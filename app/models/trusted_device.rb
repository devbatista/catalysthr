# A browser where the person chose "remember this device" after the MFA: the code is
# not asked there for 30 days (RN-02-043, D-184). A new password forgets every device.
class TrustedDevice < ApplicationRecord
  VALIDITY = 30.days

  belongs_to :user

  scope :active, -> { where(revoked_at: nil).where("expires_at > ?", Time.current) }

  # Returns the token for the browser's cookie; only its digest is kept here.
  def self.remember!(user:, user_agent:)
    token = SecureToken.generate
    create!(user: user, token_digest: SecureToken.digest(token), user_agent: user_agent.to_s.first(500),
      last_used_at: Time.current, expires_at: VALIDITY.from_now)
    token
  end

  def self.recognize(user, token)
    device = user.trusted_devices.active.find_by(token_digest: SecureToken.digest(token)) if token.present?
    device&.update_columns(last_used_at: Time.current, updated_at: Time.current)
    device
  end

  def revoke!
    update_columns(revoked_at: Time.current, updated_at: Time.current) if revoked_at.nil?
  end
end
