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

  # A code the app does not show now. A fixed one, as "000000", is accepted once in a while,
  # since the current code and its neighbors are valid.
  def wrong_otp(secret)
    totp = ROTP::TOTP.new(secret)
    valid = [ -30, 0, 30 ].map { |drift| totp.at(Time.current + drift) }
    %w[000000 111111 222222 333333].find { |code| valid.exclude?(code) }
  end
end

RSpec.configure do |config|
  config.include MfaHelper, type: :request
end
