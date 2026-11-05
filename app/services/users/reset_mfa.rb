module Users
  # Resets the MFA of a person who lost the app and the recovery codes (RN-02-044,
  # P-02-22): by who administers the profile, through the membership, or by the CatalystHR
  # support, with the reason (D-582). The person's sessions end, the remembered devices are
  # forgotten, the passkeys are removed (RN-16-076) and the person is told in the bell and
  # by e-mail (spec 15, D-607). It stays in the access events.
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
        remove_passkeys
      end
      Notifications.notify!("security.mfa_reset", user: @user, membership: @membership, brand: @brand, path: "/security",
        brand_name: @membership&.sender_name(@brand) || @brand&.commercial_name || BrandSender::PLATFORM_NAME)
      @user
    end

    private

    def remove_passkeys
      count = @user.webauthn_credentials.active.update_all(removed_at: Time.current)
      return if count.zero?

      AccessEvent.record!(kind: "auth", action: "passkeys_removed", user: @by, subject: @user, metadata: { count: count, reason: @reason }.compact)
    end
  end
end
