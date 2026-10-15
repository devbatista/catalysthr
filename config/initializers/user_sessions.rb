# Open sessions on the server (D-576). The browser's session keeps only a token; each
# request checks that its session is still open and records the activity.
Rails.application.config.after_initialize do
  token_key = "user_session_token"

  # Sign-in: opens a session for this host and brand (RN-01-003).
  Warden::Manager.after_set_user except: :fetch do |user, auth, options|
    next unless options[:scope] == :user

    request = ActionDispatch::Request.new(auth.env)
    brand_id = auth.env[HostResolver::BRAND_ID]
    auth.raw_session[token_key] = UserSession.start!(
      user: user, area: auth.env[HostResolver::AREA], brand: brand_id && Brand.find(brand_id),
      ip: request.remote_ip, user_agent: request.user_agent
    )
  end

  # Every request: a session that ended, expired or belongs to someone else signs out
  # (RN-02-050, RN-02-053, RN-02-063).
  Warden::Manager.after_set_user only: :fetch do |user, auth, options|
    next unless options[:scope] == :user

    session = UserSession.find_active(auth.raw_session[token_key])
    unless session&.user_id == user.id
      auth.logout(options[:scope])
      throw :warden, scope: options[:scope], message: :timeout
    end

    Current.user_session = session
    session.touch_activity!
  end

  Warden::Manager.before_logout do |_user, auth, options|
    next unless options[:scope] == :user

    UserSession.find_active(auth.raw_session[token_key])&.revoke!("sign_out")
  end
end
