module Processes
  # A process's document item follows the document sent for it (RN-06-010, D-642): sent
  # while the HR has not reviewed it, a correction asked, or approved, which resolves it and
  # frees the items that wait for it. Each change goes to the history (RN-06-051).
  module DocumentItem
    STATUSES = { "scanning" => "submitted", "awaiting_review" => "submitted", "ai_processing" => "submitted",
      "ai_failed" => "submitted", "approved" => "approved", "correction_requested" => "correction_requested",
      "rejected_by_scan" => "correction_requested" }.freeze
    ACTIONS = { "submitted" => "document_submitted", "approved" => "document_approved",
      "correction_requested" => "document_correction_requested" }.freeze

    module_function

    def sync(document, by:)
      item = document.process_item
      status = STATUSES[document.latest_version&.status]
      return unless item && status
      # An unfit ASO is valid, but doesn't resolve the item (RN-07-061, D-651).
      return if status == "approved" && Admissions::Aso.item?(item) && Admissions::Aso.admission_of(item)&.aso_unfit?

      changed = item.with_lock do
        next false unless item.open? && item.instance.open? && item.status != status

        approved = status == "approved"
        item.update!(status: status, completed_by: (by if approved), completed_at: (Time.current if approved),
          result: item.result.merge("document_id" => document.id))
        Events.record(item.instance, ACTIONS.fetch(status), by: by, item: item, title: item.title)
        true
      end
      UnblockItemsJob.perform_later(item) if changed && item.resolved?
    end
  end
end
