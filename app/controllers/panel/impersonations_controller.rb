module Panel
  # The subdomain's side of the impersonate (RN-02-082, RN-02-083). The link from the
  # admin area carries a one-time token; it signs the CatalystHR person in here, seeing
  # as the chosen user. Ending it goes back to the admin area.
  class ImpersonationsController < BaseController
    layout "auth"

    skip_before_action :authenticate_user!, :require_legal_acceptance, :require_mfa_setup, :set_current_company
    # The token and the running session are their own authorization.
    public_actions :show, :destroy
    real_writes_during_impersonation :destroy
    writes_while_locked :destroy

    def show
      impersonation = ImpersonationSession.redeem!(params[:token], brand: Current.brand)
      return render(:expired, status: :not_found) if impersonation.nil?

      end_impersonation(Current.impersonation, :manual) if impersonating?
      sign_out(:user) if user_signed_in?
      sign_in(:user, impersonation.impersonator)
      impersonate_user(impersonation.impersonated_user)
      session[IMPERSONATION_KEY] = impersonation.id
      Current.impersonation = impersonation
      AccessEvent.record!(kind: "impersonation", action: "start", user: impersonation.impersonated_user,
        subject: impersonation, metadata: { reason: impersonation.reason })
      redirect_to root_path
    end

    def destroy
      end_impersonation(Current.impersonation, :manual) if impersonating?
      redirect_to PlatformUrl.admin("/impersonations/new"), allow_other_host: true, notice: t("impersonations.stopped")
    end
  end
end
