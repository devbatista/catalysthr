module Documents
  # Every day, tells who sent a batch, 7 days before, that it will expire with files not
  # distributed, and expires the batches past their 30 days, deleting those files
  # (RN-08-062, P-08-17, D-644).
  class BatchExpirationsJob < ApplicationJob
    queue_as :default

    def perform
      company_ids = CrossCompany.scope(DocumentBatch, Company.all).awaiting_confirmation
        .where(expires_at: ..DocumentBatch::NOTICE_BEFORE.from_now).distinct.pluck(:company_id)
      Company.where(id: company_ids).find_each do |company|
        ActsAsTenant.with_tenant(company) { follow_company(company) }
      end
    end

    private

    def follow_company(company)
      DocumentBatch.awaiting_confirmation.where(expires_at: ..DocumentBatch::NOTICE_BEFORE.from_now).includes(:uploaded_by).find_each do |batch|
        if batch.expires_at.past?
          Batches.expire(batch)
        elsif batch.expiry_notified_at.nil? && batch.items.where(status: %w[pending confirmed]).exists?
          membership = Membership.with_access.find_by(user: batch.uploaded_by, organization: company)
          Notifications.notify!("documents.batch_expiring", user: batch.uploaded_by, membership: membership, company: company,
            subject: batch, path: "/document-batches/#{batch.id}", count: batch.items.where(status: %w[pending confirmed]).count,
            date: I18n.l(batch.expires_at.to_date))
          batch.update!(expiry_notified_at: Time.current)
        end
      end
    end
  end
end
