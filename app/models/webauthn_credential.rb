# A passkey (spec 16, RN-16-070 to RN-16-077, D-425): only the public key and the counter
# stay here; the biometrics never leave the device. It belongs to the address where it
# was registered, the brand's subdomain or the admin host (RN-16-074, RN-16-075), and
# signs in or confirms only there.
class WebauthnCredential < ApplicationRecord
  MAX_PER_USER = 10
  NICKNAME_LIMIT = 60

  belongs_to :user

  scope :active, -> { where(removed_at: nil) }
  scope :at, ->(rp_id) { where(rp_id: rp_id) }

  normalizes :nickname, with: ->(nickname) { nickname.strip }

  validates :nickname, presence: true, length: { maximum: NICKNAME_LIMIT }

  def remove!
    update!(removed_at: Time.current)
  end
end
