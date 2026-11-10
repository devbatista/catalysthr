module Documents
  # The HR's review of a version (RN-08-021 to RN-08-024): approving it makes it the one in
  # force and the previous one replaced, which only the HR still sees (D-280); asking for a
  # correction takes one of the reasons, which the employee sees (P-08-09). Never by the
  # AI (RN-08-024): the fields it read go to the record only as the HR chooses, field by field,
  # and never the person's name, CPF or birth date (RN-08-021, D-670). The dates typed here feed the expirations of block 08b (RN-08-030). The
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
    # aso_result: fit or unfit, on the ASO of an open CLT admission, with the exam's date in
    # issued_on (RN-07-061, D-651).
    # apply: the record's attributes chosen in the review, with the values as corrected
    # (RN-08-021); only the ones the type's reading may fill (Ai::ExtractionProfiles).
    def approve(issued_on: nil, valid_until: nil, aso_result: nil, apply: {})
      return error(:not_reviewable) unless @version.reviewable?
      return error(:not_applicable) unless (apply.keys.map(&:to_sym) - applicable).empty?

      admission = Admissions::Aso.admission_for(@document)
      return error(:aso_result_blank) if admission && !(aso_result.in?(%w[fit unfit]) && issued_on.present?)

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
        Admissions::Aso.record(admission, result: aso_result, exam_on: issued_on, by: @by) if admission
        apply_to_record(apply) || raise(ActiveRecord::Rollback)
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
      Notices.employee("documents.correction_requested", @document, subject: @version, reason: correction_text) if done
      after_review(done)
    end

    private

    # The attributes the type's reading may fill in the record.
    def applicable
      profile = @document.document_type.ai_extraction_profile
      profile ? Ai::ExtractionProfiles.fields(profile).filter_map(&:apply) : []
    end

    def apply_to_record(apply)
      return true if apply.empty?

      profile = @document.worker_profile
      profile.assign_attributes(apply)
      return true if profile.save

      profile.errors.full_messages.each { |message| @version.errors.add(:base, :record_invalid, detail: message) }
      false
    end

    def after_review(done)
      return false unless done

      Documents::Followers.sync(@document, by: @by)
      true
    end

    def correction_text
      reason = I18n.t("documents.correction_reasons.#{@version.correction_reason}")
      @version.correction_note ? "#{reason}: #{@version.correction_note}" : reason
    end

    def error(key, **options)
      @version.errors.add(:base, key, **options)
      false
    end
  end
end
