# The invitation e-mail, with the link to the brand's subdomain (RN-02-011).
class InvitationMailer < ApplicationMailer
  include BrandSender

  def invitation(membership, token)
    @user = membership.user
    @sender_name = membership.sender_name
    @link = membership.invitation_url(token)
    @expires_at = membership.invitation_expires_at

    mail(to: @user.email, subject: t(".subject", brand: @sender_name),
      **brand_headers(brand: membership.subdomain_brand, sender_name: @sender_name))
  end
end
