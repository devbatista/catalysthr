module Panel
  # The password asked before sensitive data is shown (RN-02-052, D-183); a passkey does
  # the same (RN-16-073), in SensitivePasskeyConfirmationsController. It is never
  # offered during an impersonate (RN-02-087). Wrong attempts are limited per address
  # (config/initializers/rack_attack.rb) and become access events.
  class SensitiveConfirmationsController < BaseController
    # Open while the contract is read only (D-624).
    writes_while_locked :create

    include SensitiveAccess

    before_action :forbidden, if: :impersonating?

    def new
      authorize! :manage, :own_security
      @return_to = safe_return_to
      @passkeys_here = FeatureFlags.enabled?(FeatureFlags::PASSKEYS) && current_user.webauthn_credentials.active.at(request.host).exists?
    end

    def create
      authorize! :manage, :own_security
      @return_to = safe_return_to
      if current_user.valid_password?(params[:password].to_s)
        confirm_sensitive_access!
        redirect_to @return_to
      else
        AccessEvent.record!(kind: "auth", action: "sensitive_confirmation_failed", user: current_user)
        flash.now[:alert] = t(".invalid_password")
        render :new, status: :unprocessable_content
      end
    end
  end
end
