module Brands
  # Every hour, asks SES about the pending and failed e-mail domains and saves the
  # status (RN-01-040, D-596). Who registered the domain and, at a partner's brand, the
  # partner's administrators are told when it is verified or fails, in the bell and by
  # e-mail (spec 15, D-607). Idempotent: the notice goes only to the run that changed the
  # status.
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
      recipients(brand).each { |user, membership| notify(brand, user, membership) }
    end

    # The CatalystHR team opens the brand in the admin; the partner's people, in the
    # partner's area.
    def notify(brand, user, membership)
      area, path = user.platform_role ? [ "admin", "/brands/#{brand.id}/edit" ] : [ "panel", "/partner/brand/edit" ]
      Notifications.notify!("brand.email_domain_status", user: user, membership: membership, brand: brand, area: area, path: path,
        subject: brand, dedup_key: "brand.email_domain_status/#{brand.id}/#{brand.email_domain_status}",
        variant: brand.email_domain_status, domain: brand.email_domain, brand_name: brand.commercial_name)
    end

    # Each person with the membership in the partner, when there is one.
    def recipients(brand)
      memberships = brand.owner.is_a?(Partner) ? Membership.active.where(organization: brand.owner).includes(:user).to_a : []
      admins = memberships.select { |membership| membership.roles.include?("partner_admin") }
      people = admins.map { |membership| [ membership.user, membership ] }
      registrar = brand.email_domain_registered_by
      if registrar && people.none? { |user, _| user == registrar }
        people << [ registrar, memberships.find { |membership| membership.user == registrar } ]
      end
      people.select { |user, _| user.active? }
    end
  end
end
