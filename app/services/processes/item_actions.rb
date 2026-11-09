module Processes
  # What the person responsible, or the HR, does on an item (spec 06, section 4, D-641):
  # a task done, an approval given or refused, a forward recorded by the HR (RN-06-066) or
  # sent to the accounting firm, which confirms it (RN-06-065, D-652), and, by the HR only,
  # an item skipped (RN-06-052). Each one goes to the history
  # (RN-06-051); a resolved item frees the ones that wait for it (UnblockItemsJob). The
  # item is locked meanwhile, so two people never resolve it twice. Returns false with the
  # errors on the item.
  class ItemActions
    def initialize(item, by:)
      @item = item
      @by = by
    end

    def complete(comment: nil)
      act("done", "item_completed", panel_kinds: %w[task], result: { "comment" => comment.to_s.strip.presence }.compact)
    end

    def approve
      act("approved", "item_approved", panel_kinds: %w[approval])
    end

    # The reason is required (RN-06-010).
    def reject(reason:)
      reason = reason.to_s.strip.presence
      return error(:reason_blank) unless reason

      act("rejected", "item_rejected", panel_kinds: %w[approval], result: { "reason" => reason }, reason: reason)
    end

    # The sending registered by hand, with its date and receipt (RN-06-066, P-06-18).
    def forward(sent_on:, receipt:)
      date = parse_date(sent_on)
      return error(:sent_on_invalid) unless date && date <= @item.instance.today
      return error(:receipt_blank) if receipt.blank?
      return error(:receipt_type) unless FileSignature.content_type(receipt)
      return error(:receipt_size, count: ProcessItem::RECEIPT_MAX_SIZE / 1.megabyte) if receipt.size > ProcessItem::RECEIPT_MAX_SIZE

      act("done", "item_forwarded", panel_kinds: %w[forward], from: %w[pending sent], result: { "sent_on" => date.iso8601 }) do
        attach_receipt(receipt) unless Simulation.active?
      end
    end

    # To the company's accounting firm, only by the HR and with every required document
    # resolved (RN-06-065, RN-07-070, D-652). Nothing is completed: the firm confirms.
    def send_to_firm
      return error(:not_actionable) unless @item.forward? && @item.pending? && @item.instance.open? && @item.instance.admission?
      return error(:documents_pending) if documents_pending?

      firm = FirmForward.linked_firm(@item.company)
      return error(:firm_missing) unless firm

      @item.with_lock do
        return error(:not_actionable) unless @item.pending?

        @item.update!(status: "sent", result: @item.result.merge("accounting_firm_id" => firm.id,
          "accounting_firm_name" => firm.name, "sent_at" => Time.current.iso8601))
        Events.record(@item.instance, "item_sent_to_firm", by: @by, item: @item, title: @item.title, firm: firm.name)
      end
      FirmForward.notify(@item)
      Dashboards::Activity.admission_forwarded(@item, by: @by)
      true
    end

    # The firm confirms what it received (RN-06-065, D-143). A cancelled admission is out
    # of the firm's reach; a concluded one may still have an optional forward.
    def confirm_receipt
      return error(:not_actionable) unless @item.forward? && @item.sent? && !@item.instance.cancelled?

      transition("received", "item_received", result: @item.result)
    end

    # The firm was unlinked before confirming (RN-02-073, D-652).
    def return_from_firm
      firm = @item.result["accounting_firm_name"]
      @item.with_lock do
        return error(:not_actionable) unless @item.sent?

        @item.update!(status: "pending", result: @item.result.except(*FirmForward::RESULT_KEYS))
        Events.record(@item.instance, "item_forward_returned", by: @by, item: @item, title: @item.title, firm: firm)
      end
      true
    end

    # The employee read the PDF and accepts it (RN-06-060, P-06-17, D-645): the version read,
    # the date, the time, the IP and the browser stay in the result.
    def acknowledge(ip:, user_agent:)
      material = @item.material
      return error(:material_not_ready) unless material&.clean?

      act("done", "item_acknowledged", panel_kinds: %w[acknowledgement],
        result: { "material_id" => material.id, "material_version" => material.version, "ip" => ip,
          "user_agent" => user_agent.to_s.first(500), "acknowledged_at" => Time.current.iso8601 })
    end

    # Any open item; a required one only with a reason (RN-06-052, P-06-15).
    def skip(reason:)
      reason = reason.to_s.strip.presence
      return error(:skip_reason_blank) if @item.required && reason.nil?
      return error(:aso_required) if Admissions::Aso.required_item?(@item)
      return error(:not_open) unless skippable? && @item.instance.open?

      transition("skipped", "item_skipped", skipped_reason: reason, reason: reason) { ProcessFormResponse.discard(@item.id) }
    end

    # A refused approval goes back to who answers for it (RN-07-083, D-648).
    def reopen
      return error(:not_open) unless @item.rejected? && @item.instance.open?

      @item.with_lock do
        @item.update!(status: "pending", completed_by: nil, completed_at: nil, result: @item.result.except("reason"))
        Events.record(@item.instance, "item_reopened", by: @by, item: @item, title: @item.title)
      end
      Notices.assigned([ @item ])
      true
    end

    private

    # The admission decides what a refused approval means (RN-07-083, D-641).
    def skippable?
      @item.open? || (@item.rejected? && @item.instance.admission?)
    end

    def documents_pending?
      @item.instance.items.document.where(required: true).any? { |item| !item.resolved? }
    end

    def act(status, action, panel_kinds:, from: %w[pending], result: {}, **details, &)
      return error(:not_actionable) unless @item.kind.in?(panel_kinds) && @item.status.in?(from) && @item.instance.open?

      transition(status, action, result: @item.result.merge(result), **details, &)
    end

    def transition(status, action, result: @item.result, skipped_reason: nil, **details)
      @item.with_lock do
        return error(:not_open) unless skippable?

        @item.update!(status: status, result: result, skipped_reason: skipped_reason, completed_by: @by,
          completed_at: Time.current)
        yield if block_given?
        Events.record(@item.instance, action, by: @by, item: @item, title: @item.title, **details)
      end
      UnblockItemsJob.perform_later(@item) if @item.resolved?
      true
    end

    def attach_receipt(receipt)
      blob = ActiveStorage::Blob.create_and_upload!(io: receipt, filename: receipt.original_filename.to_s,
        content_type: FileSignature.content_type(receipt), identify: false)
      @item.forward_receipt.attach(blob)
      FileScan.start!(blob)
    end

    def parse_date(value)
      value.is_a?(Date) ? value : Date.iso8601(value.to_s)
    rescue Date::Error
      nil
    end

    def error(key, **options)
      @item.errors.add(:base, key, **options)
      false
    end
  end
end
