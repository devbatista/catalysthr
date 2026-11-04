module Processes
  # What the person responsible, or the HR, does on an item (spec 06, section 4, D-641):
  # a task done, an approval given or refused, a forward recorded by the HR (RN-06-066)
  # and, by the HR only, an item skipped (RN-06-052). Each one goes to the history
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

      act("done", "item_forwarded", panel_kinds: %w[forward], result: { "sent_on" => date.iso8601 }) do
        attach_receipt(receipt) unless Simulation.active?
      end
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
      return error(:not_open) unless @item.open? && @item.instance.open?

      transition("skipped", "item_skipped", skipped_reason: reason, reason: reason)
    end

    private

    def act(status, action, panel_kinds:, result: {}, **details, &)
      return error(:not_actionable) unless @item.kind.in?(panel_kinds) && @item.pending? && @item.instance.open?

      transition(status, action, result: @item.result.merge(result), **details, &)
    end

    def transition(status, action, result: @item.result, skipped_reason: nil, **details)
      @item.with_lock do
        return error(:not_open) unless @item.open?

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
