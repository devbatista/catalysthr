module Documents
  # When a document expires and where it stands (spec 08, RN-08-030 to RN-08-032, D-272,
  # D-275, D-643), from the version in force: its own validity, or its date plus the
  # type's months, by the person's position when the company set them. The "age" rule only
  # checks the upload, so it never expires. The status counts in the unit's time zone, and
  # nothing is blocked by an expiration (P-08-12).
  module Expiration
    module_function

    def expires_on(document)
      version = document.current_version
      type = document.document_type
      return unless version

      if type.expires_by_document_date?
        version.valid_until
      elsif type.expires_by_periodicity? && version.issued_on
        months = type.months_for(document.worker_profile.current_employment&.effective_revision&.position)
        version.issued_on >> months if months
      end
    end

    def status(document, today = document.worker_profile.today)
      return document.current_version ? "valid" : "pending" unless document.current_version && document.expires_on

      if document.expires_on < today then "expired"
      elsif document.expires_on - document.document_type.effective_alert_days <= today then "expiring"
      else "valid"
      end
    end

    # After an approval, the date and the status of the version now in force.
    def apply(document)
      document.expires_on = expires_on(document)
      document.status = status(document)
      document.save!
    end

    # The "age" rule's check of a version's date (RN-08-033, CA-08-003): older than the
    # type takes, the review suggests "documento vencido".
    def too_old?(type, issued_on, today)
      type.expires_by_age? && issued_on.present? && issued_on + type.max_age_days < today
    end
  end
end
