module Companies
  # Tells the company's users the new address after a transfer (RN-01-052, P-01-13).
  # Who has access and who was invited is told; an e-mail already sent is not repeated
  # when the job runs again.
  class TransferNotificationJob < ApplicationJob
    queue_as :default
    retry_on StandardError, wait: :polynomially_longer, attempts: 5

    def perform(transfer)
      company = transfer.company
      Membership.where(organization: company, status: %w[active read_only invited]).includes(:user).find_each do |membership|
        next if membership.user.email.blank?

        key = "companies/transfer_notice/#{transfer.id}/#{membership.id}"
        next if Rails.cache.exist?(key)

        CompanyMailer.transferred(membership).deliver_now
        Rails.cache.write(key, true, expires_in: 7.days)
      end
    end
  end
end
