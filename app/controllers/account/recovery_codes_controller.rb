module Account
  # New recovery codes replace the previous ones (RN-02-042, P-02-20).
  class RecoveryCodesController < BaseController
    def create
      authorize! :manage, :own_security
      return redirect_to(account_root_path) unless current_user.mfa_enabled?
      return redirect_to(account_root_path, alert: t("account.invalid_password")) unless current_password_valid?

      @codes = current_user.regenerate_recovery_codes!
      render :show
    end
  end
end
