module Documents
  # Every morning, moves the documents in force to expiring and to expired, in the unit's
  # time zone (RN-08-031, RN-08-032), and on the notice's date tells the unit's HR and the
  # department's managers, once per date (D-276, D-643). The expiring document is the
  # employee's pending item in the portal (spec 16). Nothing is blocked (P-08-12).
  class ExpirationsJob < ApplicationJob
    queue_as :default

    # Within the longest notice, so a document just entering it is not missed.
    HORIZON = DocumentTypeDefinition::MAX_ALERT_DAYS.days

    def perform
      company_ids = CrossCompany.scope(Document, Company.all).kept.where(expires_on: ..(Date.current + HORIZON))
        .distinct.pluck(:company_id)
      Company.where(id: company_ids).find_each do |company|
        ActsAsTenant.with_tenant(company) { follow_company }
      end
    end

    private

    def follow_company
      Document.kept.where.not(current_version_id: nil).where(expires_on: ..(Date.current + HORIZON))
        .includes(:document_type, :current_version, worker_profile: [ :user, { employments: { revisions: %i[unit department] } } ])
        .find_each do |document|
        status = Expiration.status(document)
        document.update!(status: status) if document.status != status
        next unless status.in?(%w[expiring expired]) && document.expiration_alerted_on != document.expires_on

        Notices.expiring(document)
        document.update!(expiration_alerted_on: document.expires_on)
      end
    end
  end
end
