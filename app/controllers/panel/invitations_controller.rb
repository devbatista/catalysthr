module Panel
  # Accepting an invitation from its link (RN-02-011 to RN-02-014). A new person creates
  # the password; someone who already has one confirms it (RN-02-013). The link works
  # once, within 72 hours, and only on the subdomain of the invitation's brand.
  class InvitationsController < BaseController
    layout "auth"

    skip_before_action :authenticate_user!, :require_legal_acceptance
    public_actions :show, :update

    before_action :load_invitation

    def show
    end

    def update
      user = @membership.user
      accepted = user.password_set? ? confirm_password(user) : create_password(user)
      return render(:show, status: :unprocessable_content) unless accepted

      accept(user)
      redirect_to root_path
    end

    private

    def load_invitation
      @membership = Membership.for_brand(Current.brand).find_by_invitation_token(params[:token])
      return render(:expired, status: :not_found) unless @membership&.invitation_open?

      # Someone else signed in on this browser leaves before the invited person enters.
      sign_out(current_user) if user_signed_in? && current_user != @membership.user
    end

    # Wrong passwords count toward the lockout (RN-02-031).
    def confirm_password(user)
      return true if user.valid_for_authentication? { user.valid_password?(params[:password].to_s) }

      @error = t("devise.failure.invalid")
      false
    end

    def create_password(user)
      user.update(password: params[:password].to_s, password_confirmation: params[:password_confirmation].to_s)
    end

    def accept(user)
      @membership.with_lock do
        raise ActiveRecord::RecordNotFound unless @membership.invitation_open?

        @membership.accept_invitation!
        user.update!(status: "active") if user.deactivated?
      end
      sign_in(user)
    end
  end
end
