module Users
  # Sign-in in two steps when the person uses MFA: the password, then the code from the
  # app or a recovery code (RN-02-040 to RN-02-042). A remembered device skips the code
  # for 30 days (RN-02-043). Wrong passwords and codes add up toward the lockout (D-580).
  # People without MFA sign in through Devise, as before.
  class SessionsController < Devise::SessionsController
    PENDING_KEY = "mfa_pending"
    PENDING_VALIDITY = 5.minutes
    DEVICE_COOKIE = :trusted_device

    def create
      user = User.find_for_database_authentication(login: sign_in_params[:login])
      return super unless user&.mfa_enabled?
      return reject unless user.valid_for_authentication? { user.valid_password?(sign_in_params[:password].to_s) }
      return complete_sign_in(user) if remembered_device?(user)

      session[PENDING_KEY] = { "user_id" => user.id, "until" => PENDING_VALIDITY.from_now.to_i }
      redirect_to user_second_factor_path
    end

    def second_factor
      expired unless pending_user
    end

    def verify_second_factor
      user = pending_user
      return expired unless user

      if user.valid_for_authentication? { user.valid_second_factor?(params[:otp_code]) }
        session.delete(PENDING_KEY)
        remember_device(user) if params[:remember_device] == "1"
        complete_sign_in(user)
      elsif user.access_locked?
        session.delete(PENDING_KEY)
        redirect_to new_user_session_path, alert: t("devise.failure.invalid")
      else
        flash.now[:alert] = t(".invalid_code")
        render :second_factor, status: :unprocessable_content
      end
    end

    private

    def reject
      self.resource = User.new(login: sign_in_params[:login])
      flash.now[:alert] = t("devise.failure.invalid")
      render :new, status: :unprocessable_content
    end

    def expired
      session.delete(PENDING_KEY)
      redirect_to new_user_session_path, alert: t("users.sessions.second_factor.expired")
    end

    def pending_user
      pending = session[PENDING_KEY]
      return if pending.nil? || pending["until"].to_i < Time.current.to_i

      User.allowed_at(area: Current.area, brand: Current.brand).find_by(id: pending["user_id"])
    end

    def complete_sign_in(user)
      sign_in(resource_name, user)
      set_flash_message!(:notice, :signed_in)
      redirect_to after_sign_in_path_for(user)
    end

    def remembered_device?(user)
      remembered = cookies.encrypted[DEVICE_COOKIE]
      remembered.is_a?(Hash) && remembered["user_id"] == user.id && TrustedDevice.recognize(user, remembered["token"]).present?
    end

    def remember_device(user)
      token = TrustedDevice.remember!(user: user, user_agent: request.user_agent)
      cookies.encrypted[DEVICE_COOKIE] = {
        value: { "user_id" => user.id, "token" => token }, expires: TrustedDevice::VALIDITY.from_now, httponly: true, same_site: :lax
      }
    end
  end
end
