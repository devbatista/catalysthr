# The server's half of the passkey ceremonies (spec 16, section 4.8), on the address of the
# request: the RP ID is the brand's subdomain, or the admin host, and the name offered to the
# device is the brand's commercial name (RN-16-074, RN-16-075). Whether the device shows
# that name is up to the device (D-647). The person is always verified on the device
# (RN-16-071). A challenge serves one ceremony and lasts 5 minutes. It stays in the cache,
# which enforces the single use, with a cookie of its own: in the session cookie, a page's
# other requests answering at the same time, as the manifest's, would put back a session
# without it.
module PasskeyCeremony
  extend ActiveSupport::Concern

  CHALLENGE_COOKIE = :passkey_ceremony
  CHALLENGE_VALIDITY = 5.minutes
  # How long the device waits for the person, in milliseconds.
  DEVICE_TIMEOUT = 120_000

  included do
    before_action :require_passkeys_feature
  end

  private

  def require_passkeys_feature
    head :not_found unless FeatureFlags.enabled?(FeatureFlags::PASSKEYS)
  end

  def relying_party
    @relying_party ||= WebAuthn::RelyingParty.new(id: request.host, allowed_origins: [ request.base_url ],
      name: Current.brand&.commercial_name || BrandSender::PLATFORM_NAME, credential_options_timeout: DEVICE_TIMEOUT)
  end

  def keep_challenge(purpose, challenge, **details)
    token = SecureRandom.urlsafe_base64(32)
    Rails.cache.write(challenge_cache_key(token), { "purpose" => purpose.to_s, "challenge" => challenge, **details.stringify_keys },
      expires_in: CHALLENGE_VALIDITY)
    cookies.encrypted[CHALLENGE_COOKIE] = { value: token, expires: CHALLENGE_VALIDITY.from_now, httponly: true, same_site: :strict }
  end

  # The kept challenge, once, for whoever deletes it first. Nil when it is of another
  # ceremony or expired.
  def take_challenge(purpose)
    token = cookies.encrypted[CHALLENGE_COOKIE]
    cookies.delete(CHALLENGE_COOKIE)
    return if token.blank?

    key = challenge_cache_key(token)
    kept = Rails.cache.read(key)
    kept if kept && Rails.cache.delete(key) && kept["purpose"] == purpose.to_s
  end

  def challenge_cache_key(token)
    "passkey_challenge/#{OpenSSL::Digest::SHA256.hexdigest(token)}"
  end

  def raw_credential
    credential = params[:credential]
    credential.to_unsafe_h if credential.respond_to?(:to_unsafe_h)
  end

  # What the browser sent is checked by the gem. Anything malformed in it raises from the
  # parsers, with no error of its own: the answer is the same refused passkey.
  def parse_credential
    yield
  rescue StandardError
    nil
  end

  # The passkey of this scope that signed this challenge, with its counter moved on, or
  # nil. When a known passkey fails, it stays in @rejected_passkey, for the access event.
  def verified_passkey(challenge, scope)
    credential = parse_credential { WebAuthn::Credential.from_get(raw_credential, relying_party: relying_party) }
    passkey = credential && scope.find_by(external_id: credential.id)
    return if passkey.nil?

    valid = passkey.with_lock do
      assertion_valid?(credential, challenge, passkey) &&
        passkey.update!(sign_count: credential.sign_count, last_used_at: Time.current)
    end
    @rejected_passkey = passkey unless valid
    passkey if valid
  end

  def assertion_valid?(credential, challenge, passkey)
    handle = credential.user_handle
    return false if handle.present? && handle != passkey.user.webauthn_handle

    parse_credential do
      credential.verify(challenge, public_key: passkey.public_key, sign_count: passkey.sign_count, user_verification: true)
    end
  end

  def refuse_passkey(message)
    render json: { error: message }, status: :unprocessable_content
  end
end
