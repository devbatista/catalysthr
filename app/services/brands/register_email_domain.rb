module Brands
  # Registers the brand's e-mail domain: creates the identity in SES and keeps the DNS
  # records to show (RN-01-040, D-596). The errors stay on the brand. To change the
  # domain, it is removed first. During an impersonate simulation SES is not called
  # (RN-02-085).
  class RegisterEmailDomain
    def self.call(...) = new(...).call

    def initialize(brand:, domain:, user:)
      @brand = brand
      @domain = domain
      @user = user
    end

    def call
      return refuse(:email_domain, :already_configured) if @brand.email_domain.present?

      @brand.assign_attributes(email_domain: @domain, email_domain_status: "pending",
        email_domain_registered_by: @user, email_domain_checked_at: nil)
      return refuse(:email_domain, :blank) if @brand.email_domain.blank?
      return @brand unless @brand.valid?

      @brand.email_domain_records = Simulation.active? ? [] : EmailIdentity.create(@brand.email_domain)
      @brand.save!
      @brand
    rescue EmailIdentity::AlreadyExists
      refuse(:email_domain, :unavailable)
    rescue EmailIdentity::Unavailable
      refuse(:base, :ses_unavailable)
    end

    private

    def refuse(attribute, error)
      @brand.errors.add(attribute, error)
      @brand
    end
  end
end
