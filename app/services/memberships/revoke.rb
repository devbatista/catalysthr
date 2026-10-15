module Memberships
  # Removes a person's access to the organization, or cancels a pending invitation
  # (RN-02-060). Without any other membership left, the account is deactivated
  # (RN-02-062). The sessions end at once (RN-02-063, in Membership).
  class Revoke
    def self.call(**)
      new(**).call
    end

    def initialize(membership:, by:)
      @membership = membership
      @by = by
    end

    def call
      action = @membership.invited? ? "invitation_cancelled" : "access_revoked"
      Memberships.ensure_hr_admin_remains!(@membership, removing: @membership.roles.include?("hr_admin"))

      Membership.transaction do
        @membership.update!(status: "revoked", invitation_token_digest: nil)
        user = @membership.user
        if user.platform_role.nil? && !user.memberships.where.not(status: "revoked").exists?
          user.update!(status: "deactivated")
        end
      end
      AccessEvent.record!(kind: "admin", action: action, user: @by, subject: @membership)
      @membership
    end
  end
end
