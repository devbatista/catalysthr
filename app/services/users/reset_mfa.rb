module Users
  # Resets the MFA of a person who lost the app and the recovery codes (RN-02-044,
  # P-02-22): by who administers the profile, through the membership, or by the CatalystHR
  # support, with the reason (D-582). The person's sessions end, the remembered devices are
  # forgotten, and the person is told in the bell and by e-mail (spec 15, D-607). It stays in
  # the access events.
  class ResetMfa
    def self.call(**)
      new(**).call
    end

    # membership and brand say on whose behalf the notice goes; without them, CatalystHR.
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
      Notifications.notify!("security.mfa_reset", user: @user, membership: @membership, brand: @brand, path: "/security",
        brand_name: @membership&.sender_name(@brand) || @brand&.commercial_name || BrandSender::PLATFORM_NAME)
      @user
    end
  end
end
