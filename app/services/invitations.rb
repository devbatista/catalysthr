# Invitations to a membership (spec 02, RN-02-010 to RN-02-013).
module Invitations
  # An issued invitation. The token exists only here and in the link. The brand is the
  # one whose subdomain the link opens: the membership's own, or, for an accounting
  # firm, the brand of the company or of the panel the invitation comes from (D-586).
  Invitation = Data.define(:membership, :token, :brand) do
    def link
      membership.invitation_url(token, brand: brand)
    end
  end

  module_function

  def issue(membership, channels:, invited_by:, brand: nil)
    brand ||= membership.subdomain_brand
    membership.invitation_channels = channels
    refuse(membership, :invitation_channels, :email_missing) if channels.include?("email") && membership.user.email.blank?
    # The e-mail bounced: the inviter corrects the contact or hands over the link (D-609).
    refuse(membership, :invitation_channels, :email_bounced) if channels.include?("email") && membership.user.email_bounced?
    refuse(membership, :base, :without_subdomain) if brand&.active_subdomain.nil?

    Invitation.new(membership, membership.issue_invitation!(channels: channels, invited_by: invited_by), brand)
  end

  def refuse(membership, attribute, error)
    membership.errors.add(attribute, error)
    raise ActiveRecord::RecordInvalid, membership
  end

  def deliver(invitation)
    return unless invitation.membership.invitation_channels.include?("email")

    DeliverJob.perform_later(invitation.membership, invitation.token, invitation.brand)
  end
end
