# Messages to an accounting firm's administrators, on behalf of the brand of the
# company that wrote (D-586, RN-01-040).
class AccountingFirmMailer < ApplicationMailer
  include BrandSender

  # D-590: a company asked to link the firm, which accepts or refuses in its area.
  def link_requested(link, user)
    @user = user
    @company = link.company
    @firm = link.accounting_firm
    brand = @company.subdomain_brand
    @link = brand.panel_url("/firm")

    mail(to: user.email, subject: t(".subject", company: @company.name), **brand_headers(brand: brand))
  end
end
