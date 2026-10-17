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
      Membership.transaction do
        Memberships.ensure_admin_remains!(@membership, keeping_roles: [])
        @membership.update!(status: "revoked", invitation_token_digest: nil)
        # A consultant invited again starts without companies (D-052).
        @membership.partner_membership_companies.destroy_all
        Memberships.release_company_assignments!(@membership)
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
