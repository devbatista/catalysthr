module Users
  # Who administers the profile resets the MFA of a person who lost the app and the
  # recovery codes (RN-02-044, P-02-22). The person's sessions end, the remembered devices
  # are forgotten, and the person is told by e-mail. It stays in the access events.
  class ResetMfa
    def self.call(**)
      new(**).call
    end

    def initialize(membership:, by:)
      @membership = membership
      @by = by
    end

    def call
      user = @membership.user
      User.transaction do
        user.disable_mfa!(by: @by)
        user.revoke_sessions!(reason: "mfa_reset")
        user.trusted_devices.active.update_all(revoked_at: Time.current)
      end
      AccountMailer.mfa_reset(@membership).deliver_later if user.email.present?
      user
    end
  end
end
