module Invitations
  # Sends the invitation again with a new token; the previous link stops working
  # (RN-02-012, P-02-07, CA-02-002).
  class Resend
    def self.call(**)
      new(**).call
    end

    def initialize(membership:, channels:, invited_by:, brand: nil)
      @membership = membership
      @brand = brand
      @channels = Array(channels).map(&:to_s)
      @invited_by = invited_by
    end

    def call
      Invitations.refuse(@membership, :base, :not_invited) unless @membership.invited?

      invitation = Invitations.issue(@membership, channels: @channels, invited_by: @invited_by, brand: @brand)
      Invitations.deliver(invitation)
      invitation
    end
  end
end
