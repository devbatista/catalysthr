module Brands
  # Removes the brand's e-mail domain and its SES identity; the e-mails go back to the
  # platform's address (D-596). Returns false when SES did not answer.
  class RemoveEmailDomain
    def self.call(brand:)
      EmailIdentity.delete(brand.email_domain) if brand.email_domain.present? && !Simulation.active?
      brand.update!(email_domain: nil, email_domain_status: nil, email_domain_records: [],
        email_domain_checked_at: nil, email_domain_registered_by: nil)
    rescue EmailIdentity::Unavailable
      false
    end
  end
end
