module Panel
  # The password asked before sensitive data is shown (RN-02-052, D-183). It is never
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

    private

    # Only a path of this site, never another host.
    def safe_return_to
      path = params[:return_to].to_s
      path.start_with?("/") && !path.start_with?("//") && !path.include?("\\") ? path : root_path
    end
  end
end
