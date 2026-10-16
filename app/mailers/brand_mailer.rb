# Notices about a brand's settings, on behalf of the brand (RN-01-040, D-596).
class BrandMailer < ApplicationMailer
  include BrandSender

  # The e-mail domain was verified in SES or failed.
  def email_domain_status(brand, user)
    @user = user
    @brand = brand
    @verified = brand.email_domain_verified?
    @link = user.platform_role ? PlatformUrl.admin("/brands/#{brand.id}/edit") : brand.panel_url("/partner/brand/edit")
    key = @verified ? ".verified_subject" : ".failed_subject"

    mail(to: user.email, subject: t(key, domain: brand.email_domain), **brand_headers(brand: brand))
  end
end
