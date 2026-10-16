module Users
  # Resets the MFA of a person who lost the app and the recovery codes (RN-02-044,
  # P-02-22): by who administers the profile, through the membership, or by the CatalystHR
  # support, with the reason (D-582). The person's sessions end, the remembered devices are
  # forgotten, and the person is told by e-mail. It stays in the access events.
  class ResetMfa
    def self.call(**)
      new(**).call
    end

    # membership and brand say on whose behalf the e-mail goes; without them, CatalystHR.
    def initialize(user:, by:, membership: nil, brand: nil, reason: nil)
      @user = user
      @by = by
      @membership = membership
      @brand = brand
      @reason = reason
    end

    def call
      User.transaction do
        @user.disable_mfa!(by: @by, reason: @reason)
        @user.revoke_sessions!(reason: "mfa_reset")
        @user.trusted_devices.active.update_all(revoked_at: Time.current)
      end
      AccountMailer.mfa_reset(@user, @membership, @brand).deliver_later if @user.email.present?
      @user
    end
  end
end
