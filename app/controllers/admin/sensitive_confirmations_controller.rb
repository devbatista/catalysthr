module Admin
  # The team's password asked again before people's data, in the assisted import (RN-02-052,
  # RN-18-041, D-666): it holds 5 minutes in the session, as in the panel (SensitiveAccess).
  # Wrong attempts become access events.
  class SensitiveConfirmationsController < BaseController
    include SensitiveAccess

    def new
      authorize! :read, :admin_home
      @return_to = safe_return_to
    end

    def create
      authorize! :read, :admin_home
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
