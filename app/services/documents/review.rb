module Documents
  # The HR's review of a version (RN-08-021 to RN-08-024): approving it makes it the one in
  # force and the previous one replaced, which only the HR still sees (D-280); asking for a
  # correction takes one of the reasons, which the employee sees (P-08-09). Never by the
  # AI (RN-08-024). The dates typed here feed the expirations of block 08b (RN-08-030). The
  # version is locked meanwhile, so two people never review it twice. Returns false with
  # the errors on the version.
  class Review
    def initialize(version, by:)
      @version = version
      @document = version.document
      @by = by
    end

    # A date older than the "age" rule takes is not approved: the review suggests asking
    # the correction "documento vencido" (RN-08-033, CA-08-003).
    def approve(issued_on: nil, valid_until: nil)
      return error(:not_reviewable) unless @version.reviewable?

      type = @document.document_type
      if Expiration.too_old?(type, issued_on, @document.worker_profile.today)
        return error(:too_old, count: type.max_age_days)
      end

      done = @version.with_lock do
        next error(:not_reviewable) unless @version.reviewable?

        previous = @document.versions.where(status: "approved").where.not(id: @version.id)
        previous.find_each { |version| version.update!(status: "replaced") }
        @version.update!(status: "approved", reviewed_by: @by, reviewed_at: Time.current, issued_on: issued_on.presence,
          valid_until: valid_until.presence)
        @document.current_version = @version
        Expiration.apply(@document)
        true
      end
      after_review(done)
    end

    def request_correction(reason:, note: nil)
      return error(:not_reviewable) unless @version.reviewable?

      done = @version.with_lock do
        next error(:not_reviewable) unless @version.reviewable?

        @version.assign_attributes(status: "correction_requested", correction_reason: reason.presence, correction_note: note,
          reviewed_by: @by, reviewed_at: Time.current)
        @version.save || raise(ActiveRecord::Rollback)
      end
      after_review(done)
    end

    private

    def after_review(done)
      return false unless done

      Documents::Followers.sync(@document, by: @by)
      true
    end

    def error(key, **options)
      @version.errors.add(:base, key, **options)
      false
    end
  end
end
