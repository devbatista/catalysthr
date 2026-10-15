# Security notices about a person's account, sent on behalf of the brand of the
# membership (RN-01-040).
class AccountMailer < ApplicationMailer
  include BrandSender

  # Access codes and security notices (RN-20-011).
  self.deliver_later_queue_name = :critical

  # RN-02-044: the person is told that the MFA was reset.
  def mfa_reset(membership, brand = nil)
    prepare(membership, brand)
    mail(to: @user.email, subject: t(".subject", brand: @sender_name), **@headers)
  end

  # D-582: the old e-mail is told that the contact changed, without the new one.
  def contact_changed(membership, old_email, brand = nil)
    prepare(membership, brand)
    mail(to: old_email, subject: t(".subject", brand: @sender_name), **@headers)
  end

  private

  # An accounting firm's membership has no brand of its own; the brand where the change
  # was made is given (D-586).
  def prepare(membership, brand)
    brand ||= membership.subdomain_brand
    @user = membership.user
    @sender_name = membership.sender_name(brand)
    @headers = brand_headers(brand: brand, sender_name: @sender_name)
  end
end
