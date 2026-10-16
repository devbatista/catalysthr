module Brands
  # Every hour, asks SES about the pending and failed e-mail domains and saves the
  # status (RN-01-040, D-596). Who registered the domain and, at a partner's brand, the
  # partner's administrators are told when it is verified or fails. Idempotent: the
  # notice goes only to the run that changed the status.
  class VerifyEmailDomainJob < ApplicationJob
    queue_as :default

    def perform
      Brand.where(email_domain_status: %w[pending failed]).where.not(email_domain: nil).find_each do |brand|
        check(brand)
      rescue EmailIdentity::Unavailable
        next
      end
    end

    private

    def check(brand)
      status = EmailIdentity.status(brand.email_domain)
      changed = Brand.where(id: brand.id, email_domain: brand.email_domain, email_domain_status: brand.email_domain_status)
        .update_all(email_domain_status: status, email_domain_checked_at: Time.current, updated_at: Time.current)
      return unless changed == 1 && status != brand.email_domain_status && status.in?(%w[verified failed])

      brand.reload
      recipients(brand).each { |user| BrandMailer.email_domain_status(brand, user).deliver_later }
    end

    def recipients(brand)
      users = [ brand.email_domain_registered_by ]
      if brand.owner.is_a?(Partner)
        users += Membership.active.with_role("partner_admin").where(organization: brand.owner).includes(:user).map(&:user)
      end
      users.compact.uniq.select { |user| user.active? && user.email.present? }
    end
  end
end
