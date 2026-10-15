# Open sessions on the server (D-576). The browser's session keeps only a token; each
# request checks that its session is still open and records the activity. Sign-in,
# failed sign-in and sign-out become access events (RN-05-020).
Rails.application.config.after_initialize do
  token_key = "user_session_token"
  ended_key = "catalysthr.session_ended"

  # Sign-in: opens a session for this host and brand (RN-01-003).
  Warden::Manager.after_set_user except: :fetch do |user, auth, options|
    next unless options[:scope] == :user

    request = ActionDispatch::Request.new(auth.env)
    brand_id = auth.env[HostResolver::BRAND_ID]
    auth.raw_session[token_key] = UserSession.start!(
      user: user, area: auth.env[HostResolver::AREA], brand: brand_id && Brand.find(brand_id),
      ip: request.remote_ip, user_agent: request.user_agent
    )
    # Devise's strategies sign in with :authentication and sign_in with :set_user (after
    # the MFA code, after the invitation). bypass_sign_in runs no callbacks.
    AccessEvent.record!(kind: "auth", action: "sign_in", user: user,
      metadata: { area: auth.env[HostResolver::AREA].to_s, brand_id: brand_id }.compact)
  end

  # Every request: a session that ended, expired or belongs to someone else signs out
  # (RN-02-050, RN-02-053, RN-02-063).
  Warden::Manager.after_set_user only: :fetch do |user, auth, options|
    next unless options[:scope] == :user

    session = UserSession.find_active(auth.raw_session[token_key])
    unless session&.user_id == user.id
      auth.env[ended_key] = true
      auth.logout(options[:scope])
      throw :warden, scope: options[:scope], message: :timeout
    end

    Current.user_session = session
    session.touch_activity!
  end

  # A session that ended by itself is not a sign-out.
  Warden::Manager.before_logout do |user, auth, options|
    next unless options[:scope] == :user && !auth.env[ended_key]

    UserSession.find_active(auth.raw_session[token_key])&.revoke!("sign_out")
    AccessEvent.record!(kind: "auth", action: "sign_out", user: user) if user
  end

  # Wrong password for a person who exists. Unknown CPFs and e-mails are not recorded:
  # there is nobody to attach them to, and Rack::Attack limits them (RN-02-032).
  Warden::Manager.before_failure do |env, options|
    # Warden has already pointed PATH_INFO to the failure app; the original path is kept.
    request = Rack::Request.new(env)
    next unless options[:scope] == :user && request.post? && options[:attempted_path] == "/entrar"

    user = User.find_by_login(request.params.dig("user", "login"))
    AccessEvent.record!(kind: "auth", action: "sign_in_failed", user: user, metadata: { step: "password" }) if user
  end
end
