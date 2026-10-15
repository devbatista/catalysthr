# Invitations to a membership (spec 02, RN-02-010 to RN-02-013).
module Invitations
  # An issued invitation. The token exists only here and in the link.
  Invitation = Data.define(:membership, :token) do
    def link
      membership.invitation_url(token)
    end
  end

  module_function

  def issue(membership, channels:, invited_by:)
    membership.invitation_channels = channels
    refuse(membership, :invitation_channels, :email_missing) if channels.include?("email") && membership.user.email.blank?
    refuse(membership, :base, :without_subdomain) if membership.subdomain_brand&.active_subdomain.nil?

    Invitation.new(membership, membership.issue_invitation!(channels: channels, invited_by: invited_by))
  end

  def refuse(membership, attribute, error)
    membership.errors.add(attribute, error)
    raise ActiveRecord::RecordInvalid, membership
  end

  def deliver(invitation)
    DeliverJob.perform_later(invitation.membership, invitation.token) if invitation.membership.invitation_channels.include?("email")
  end
end
