# Notices about the company, on behalf of the brand it is reached through (RN-01-040).
class CompanyMailer < ApplicationMailer
  include BrandSender

  # RN-01-052: the company now opens at the new owner's subdomain. The old address does
  # not redirect (P-01-13).
  def transferred(membership)
    @user = membership.user
    brand = membership.subdomain_brand
    @sender_name = membership.sender_name(brand)
    @company = membership.organization
    @link = brand.panel_url

    mail(to: @user.email, subject: t(".subject", company: @company.name), **brand_headers(brand: brand, sender_name: @sender_name))
  end
end
