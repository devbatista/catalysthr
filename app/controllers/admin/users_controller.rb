module Admin
  # The support corrects the contact or resets the MFA of a client's user who also
  # reaches another organization, which the organization's administrators cannot do
  # (D-582, RN-02-044, P-02-17). Always with the reason, which goes to the access event.
  class UsersController < BaseController
    before_action :load_user, only: %i[contact reset_mfa]

    def index
      authorize! :read, User.new
      @cpf = params[:cpf].to_s
      @user = User.where(platform_role: nil).find_by(cpf: Cpf.normalize(@cpf)) if Cpf.valid?(@cpf)
    end

    def contact
      authorize! :correct_contact, @user
      return redirect_back_to_user(alert: t(".reason_required")) if reason.blank?

      Users::CorrectContact.call(user: @user, email: params[:email].presence, mobile_phone: params[:mobile_phone].presence,
        by: current_user, reason: reason)
      redirect_back_to_user(notice: t(".corrected"))
    rescue ActiveRecord::RecordInvalid => error
      redirect_back_to_user(alert: error.record.errors.full_messages.to_sentence)
    end

    def reset_mfa
      authorize! :reset_mfa, @user
      return redirect_back_to_user(alert: t(".reason_required")) if reason.blank?

      Users::ResetMfa.call(user: @user, by: current_user, reason: reason)
      redirect_back_to_user(notice: t(".reset"))
    end

    private

    def load_user
      @user = User.where(platform_role: nil).find(params[:id])
    end

    def reason
      params[:reason].to_s.strip.first(500).presence
    end

    def redirect_back_to_user(**flash)
      redirect_to admin_users_path(cpf: @user.cpf), **flash
    end
  end
end
