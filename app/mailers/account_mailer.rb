# The notice to the old e-mail of a person's account, sent on behalf of the brand of the
# membership (RN-01-040), or of CatalystHR when the support made the change (D-582). It
# belongs to no one in the system, so it stays out of the notices (D-607); the others go
# through Notifications (spec 15).
class AccountMailer < ApplicationMailer
  include BrandSender

  # Access codes and security notices (RN-20-011).
  self.deliver_later_queue_name = :critical

  # D-582: the old e-mail is told that the contact changed, without the new one.
  def contact_changed(user, old_email, membership = nil, brand = nil)
    prepare(user, membership, brand)
    mail(to: old_email, subject: t(".subject", brand: @sender_name), **@headers)
  end

  private

  # An accounting firm's membership has no brand of its own; the brand where the change
  # was made is given (D-586).
  def prepare(user, membership, brand)
    brand ||= membership&.subdomain_brand
    @user = user
    @sender_name = membership&.sender_name(brand) || brand&.commercial_name || PLATFORM_NAME
    @headers = brand_headers(brand: brand, sender_name: @sender_name)
  end
end
