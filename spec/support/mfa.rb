# MFA in request specs (RN-02-040 to RN-02-042).
module MfaHelper
  def enable_mfa(user)
    user.update!(otp_secret: User.generate_otp_secret, otp_required_for_login: true)
    user
  end

  # Signs in with the password and the current code from the app.
  def sign_in_with_mfa(login, user, password: "Catalyst#2026")
    post "/sign-in", params: { user: { login: login, password: password } }
    post "/sign-in/code", params: { otp_code: user.reload.current_otp }
  end
end

RSpec.configure do |config|
  config.include MfaHelper, type: :request
end
