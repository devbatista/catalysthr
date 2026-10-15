module Invitations
  # Sends the invitation by e-mail (spec 02, section 8). WhatsApp comes with Twilio.
  # A token replaced or used meanwhile is skipped, so a retry never sends a dead link.
  class DeliverJob < ApplicationJob
    queue_as :critical

    def perform(membership, token)
      return unless membership.invitation_open?
      return unless membership.invitation_token_digest == Membership.token_digest(token)

      InvitationMailer.invitation(membership, token).deliver_now
    end
  end
end
