# A browser or installed PWA allowed to get push (spec 15, RN-15-003, RN-15-004). It belongs
# to the account and to the brand whose address it was made at, so a person in two brands
# gets each brand's notices on the right app. Not tenant-scoped: it has no company.
class PushSubscription < ApplicationRecord
  # The push services of the browsers. The server posts to this address, which comes from
  # the browser, so an address outside these never gets in (no SSRF).
  SERVICE_HOSTS = /\A(fcm\.googleapis\.com|([a-z0-9-]+\.)*push\.services\.mozilla\.com|([a-z0-9-]+\.)*push\.apple\.com|[a-z0-9-]+\.notify\.windows\.com)\z/
  P256DH_BYTES = 65
  AUTH_BYTES = 16

  belongs_to :user
  belongs_to :brand

  validates :endpoint, presence: true, uniqueness: true
  validate :endpoint_of_a_push_service
  validate :keys_of_the_browser

  def self.service?(endpoint)
    uri = URI.parse(endpoint.to_s)
    uri.is_a?(URI::HTTPS) && uri.port == 443 && uri.userinfo.nil? && uri.host.to_s.match?(SERVICE_HOSTS)
  rescue URI::InvalidURIError
    false
  end

  private

  def endpoint_of_a_push_service
    errors.add(:endpoint, :invalid) unless self.class.service?(endpoint)
  end

  def keys_of_the_browser
    errors.add(:p256dh, :invalid) unless decoded_size(p256dh) == P256DH_BYTES
    errors.add(:auth, :invalid) unless decoded_size(auth) == AUTH_BYTES
  end

  def decoded_size(value)
    Base64.urlsafe_decode64(value.to_s).bytesize
  rescue ArgumentError
    0
  end
end
