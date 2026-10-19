module Account
  # Authenticator app (RN-02-042). The secret stays in the session until the first code
  # proves the app works; the recovery codes are shown only once.
  class MfaController < BaseController
    SECRET_KEY = "mfa_setup_secret"

    def new
      authorize! :manage, :own_security
      return redirect_to(account_root_path) if current_user.mfa_enabled?

      session[SECRET_KEY] ||= User.generate_otp_secret
      @secret = session[SECRET_KEY]
    end

    # A second send of the same form waits for the first one. When the first one already
    # turned MFA on, the code was used there, so the person goes to the security page,
    # where new recovery codes can be made, instead of reading "invalid code".
    def create
      authorize! :manage, :own_security
      @secret = session[SECRET_KEY]
      return redirect_to(account_root_path, notice: t(".already_enabled")) if current_user.mfa_enabled?
      return redirect_to(new_account_mfa_path) if @secret.blank?

      already_enabled = current_user.with_lock do
        next true if current_user.mfa_enabled?

        @codes = current_user.enable_mfa!(secret: @secret, code: params[:otp_code].to_s)
        false
      end
      return redirect_to(account_root_path, notice: t(".already_enabled")) if already_enabled

      if @codes
        session.delete(SECRET_KEY)
        render "account/recovery_codes/show"
      else
        flash.now[:alert] = t(".invalid_code")
        render :new, status: :unprocessable_content
      end
    end

    # Only who is not required to use MFA can turn it off (RN-02-040).
    def destroy
      authorize! :manage, :own_security
      if current_user.mfa_required?
        redirect_to account_root_path, alert: t(".required")
      elsif current_password_valid?
        current_user.disable_mfa!
        redirect_to account_root_path, notice: t(".disabled")
      else
        redirect_to account_root_path, alert: t("account.invalid_password")
      end
    end
  end
end
