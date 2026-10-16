module Panel
  # The company's side of the support's entry (D-581): the link from the admin area
  # carries a one-time token, which signs the support in at the company's subdomain.
  # Ending it goes back to the admin area.
  class SupportAccessesController < BaseController
    layout "auth"

    skip_before_action :authenticate_user!, :require_legal_acceptance, :require_mfa_setup, :set_current_company
    # The token and the running entry are their own authorization.
    public_actions :show, :destroy

    def show
      access = SupportAccess.redeem!(params[:token], brand: Current.brand)
      return render(:expired, status: :not_found) if access.nil?

      end_support_access(Current.support_access, :manual) if Current.support_access
      end_impersonation(Current.impersonation, :manual) if impersonating?
      sign_out(:user) if user_signed_in?
      sign_in(:user, access.support_user)
      session[SUPPORT_ACCESS_KEY] = access.id
      session[Panel::BaseController::CURRENT_COMPANY_KEY] = access.company_id
      AccessEvent.record!(kind: "auth", action: "support_access_started", user: access.support_user, subject: access,
        company: access.company, metadata: { reason: access.reason })
      redirect_to root_path
    end

    def destroy
      end_support_access(Current.support_access, :manual) if Current.support_access
      redirect_to PlatformUrl.admin("/support-accesses/new"), allow_other_host: true, notice: t("support_accesses.stopped")
    end
  end
end
