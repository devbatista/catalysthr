# Request limits (RN-02-032, P-02-15, RN-20-055). They stop one address from trying
# many CPFs; the lockout after 5 wrong passwords (RN-02-031) protects each account.
# Counters live in the Rails cache (Solid Cache, D-511).
#
# The limits are not in the spec. They leave room for a company where many people
# sign in from the same office address.
class Rack::Attack
  SIGN_IN_PATHS = %w[/entrar /entrar/codigo].freeze
  RECOVERY_PATHS = %w[/senha /desbloqueio].freeze
  INVITATION_PATH = "/convite"

  # Sign-in attempts per address, with the password or the MFA code.
  throttle("sign_in/ip", limit: 30, period: 1.minute) do |request|
    request.ip if request.post? && SIGN_IN_PATHS.include?(request.path)
  end

  # Recovery and unlock requests per address, so nobody floods the e-mails.
  throttle("recovery/ip", limit: 10, period: 15.minutes) do |request|
    request.ip if request.post? && RECOVERY_PATHS.include?(request.path)
  end

  # Recovery and unlock requests for the same CPF or e-mail, from any address. The key
  # is a digest, so no CPF or e-mail is kept in the cache.
  throttle("recovery/login", limit: 5, period: 15.minutes) do |request|
    next unless request.post? && RECOVERY_PATHS.include?(request.path)

    login = request.params.dig("user", "login").to_s.strip.downcase
    login = Cpf.normalize(login) if Cpf.looks_like_cpf?(login)
    OpenSSL::Digest::SHA256.hexdigest(login) if login.present?
  end

  # Password attempts on invitation links, which count toward the lockout too.
  throttle("invitation/ip", limit: 10, period: 15.minutes) do |request|
    request.ip if request.patch? && request.path == INVITATION_PATH
  end

  self.throttled_responder = lambda do |_request|
    [ 429, { "content-type" => "text/plain; charset=utf-8" }, [ I18n.t("rack_attack.throttled") ] ]
  end
end
