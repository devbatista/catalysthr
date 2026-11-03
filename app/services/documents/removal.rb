module Documents
  # The HR administrator's deletion of a document and its recovery (RN-08-083, P-03-19,
  # P-08-22, D-644, CA-08-010): with a reason, it leaves the folder at once; its files stay
  # 30 days, then PurgeDeletedJob deletes them, and the recovery ends. A document still
  # answering an open process item or an acknowledgment waiting is not deleted; one of a
  # request gives the request a new pending document. Generated ones are never deleted from
  # the folder (RN-08-070). Each step is in the trail. Returns false with the errors on the
  # document.
  class Removal
    RECOVERABLE_FOR = 30.days

    def initialize(document, by:)
      @document = document
      @by = by
    end

    def delete(reason:)
      reason = reason.to_s.strip.presence
      return error(:delete_reason_blank) unless reason
      return error(:read_only) if @document.read_only?
      return error(:process_item_open) if @document.process_item&.open?
      return error(:acknowledgment_awaiting) if @document.acknowledgments.awaiting.exists?

      @document.with_lock do
        next error(:already_deleted) if @document.deleted_at

        @document.update!(deleted_at: Time.current, deleted_by: @by, delete_reason: reason)
        reopen_requests
        true
      end
    end

    def restore
      return error(:not_recoverable) unless self.class.recoverable?(@document)

      @document.update!(deleted_at: nil, deleted_by: nil, delete_reason: nil)
      true
    end

    def self.recoverable?(document)
      document.deleted_at.present? && document.purged_at.nil? && document.deleted_at > RECOVERABLE_FOR.ago
    end

    private

    # The person still owes the requested document (RN-08-041).
    def reopen_requests
      @document.request_targets.find_each do |target|
        pending = Document.create!(worker_profile: @document.worker_profile, document_type: @document.document_type, source: "hr",
          source_ref: target.request)
        target.update!(document: pending, status: "pending")
      end
    end

    def error(key)
      @document.errors.add(:base, key)
      false
    end
  end
end
