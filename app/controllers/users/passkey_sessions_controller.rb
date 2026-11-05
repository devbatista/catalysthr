module Users
  # Signing in with a passkey (RN-16-071, RN-16-072, D-426): the button on the sign-in page
  # and the browser's autofill. It fulfills the MFA, so no code is asked. Only who may sign
  # in at this address is found (RN-02-004), and a locked or deactivated account stays out.
  # A failed passkey does not count toward the lockout: the limit is per address, since
  # the credential's identifier alone could lock someone else out.
  class PasskeySessionsController < Devise::SessionsController
    include PasskeyCeremony

    prepend_before_action :require_no_authentication, only: :challenge

    def challenge
      options = relying_party.options_for_authentication(user_verification: "required")
      keep_challenge(:sign_in, options.challenge)
      render json: options
    end

    def create
      kept = take_challenge(:sign_in)
      return refuse_passkey(t(".expired")) if kept.nil?

      passkey = verified_passkey(kept["challenge"], allowed_passkeys)
      user = passkey&.user
      return refuse(user || @rejected_passkey&.user) unless user&.active_for_authentication?

      request.env["catalysthr.sign_in_method"] = "passkey"
      sign_in(resource_name, user)
      set_flash_message!(:notice, :signed_in)
      render json: { redirect_to: after_sign_in_path_for(user) }
    end

    private

    def allowed_passkeys
      WebauthnCredential.active.at(request.host).where(user: User.allowed_at(area: Current.area, brand: Current.brand))
    end

    def refuse(user)
      user&.record_auth_event("sign_in_failed", step: "passkey")
      refuse_passkey(t(".refused"))
    end
  end
end
