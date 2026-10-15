# Sign-in, password recovery and lockout (spec 02). The User model chooses the
# modules; the rules from the spec are here.
Devise.setup do |config|
  require "devise/orm/active_record"

  config.mailer = "UserMailer"
  config.parent_controller = "ApplicationController"
  config.scoped_views = true

  # One field for CPF or e-mail (RN-02-003, P-02-05). User.find_by_login decides.
  config.authentication_keys = [ :login ]
  config.case_insensitive_keys = []
  config.strip_whitespace_keys = [ :login ]
  config.skip_session_storage = [ :http_auth ]
  config.http_authenticatable = false

  # Answers never reveal whether a CPF or e-mail exists (RN-02-034, P-01-03).
  config.paranoid = true

  config.stretches = Rails.env.test? ? 1 : 12
  # Password rules are in PasswordPolicyValidator (RN-02-030).
  config.password_length = 8..72

  # Recovery link valid for 2 hours (RN-02-033, P-02-16).
  config.reset_password_within = 2.hours
  config.sign_in_after_reset_password = false

  # 5 wrong attempts lock the account until the unlock by e-mail (RN-02-031, D-181).
  # The counter is per user, across brands (P-02-14). The WhatsApp code comes with Twilio.
  config.lock_strategy = :failed_attempts
  config.unlock_strategy = :email
  config.maximum_attempts = 5
  config.last_attempt_warning = false

  # Recovery codes are checked in the second step of Users::SessionsController. Left in
  # Warden, the two_factor_backupable strategy would run after a wrong password and count
  # it again, locking the account at the third attempt instead of the fifth.
  config.warden do |manager|
    manager.default_strategies(scope: :user).delete(:two_factor_backupable)
  end

  config.expire_all_remember_me_on_sign_out = true
  config.sign_out_via = :delete
  config.responder.error_status = :unprocessable_content
  config.responder.redirect_status = :see_other
end
