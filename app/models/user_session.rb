# An open session, checked on every request (D-576). It ends after the inactivity time
# (RN-02-050, RN-02-051), at sign-out, when the password changes (RN-02-053), when the
# person ends it from another device, or when the access that held it is removed
# (RN-02-063).
class UserSession < ApplicationRecord
  # 30 minutes for everyone, 14 days for who is only an employee at the brand (D-089).
  # Holding both, the stricter wins (P-02-24).
  STAFF_INACTIVITY = 30.minutes
  EMPLOYEE_INACTIVITY = 14.days
  # Activity is written at most once a minute, to keep requests light.
  TOUCH_INTERVAL = 1.minute

  belongs_to :user
  belongs_to :brand, optional: true

  enum :area, { admin: "admin", panel: "panel" }, validate: true

  scope :active, -> { where(revoked_at: nil).where("expires_at > ?", Time.current) }

  # Returns the token for the browser's session; only its digest is kept here.
  def self.start!(user:, area:, brand:, ip:, user_agent:)
    token = SecureToken.generate
    now = Time.current
    create!(user: user, area: area, brand: brand, ip: ip, user_agent: user_agent.to_s.first(500),
      token_digest: SecureToken.digest(token), last_seen_at: now, expires_at: now + inactivity_for(user, area, brand))
    token
  end

  def self.find_active(token)
    active.find_by(token_digest: SecureToken.digest(token)) if token.present?
  end

  def self.inactivity_for(user, area, brand)
    return STAFF_INACTIVITY unless area.to_s == "panel"

    roles = Membership.with_access.for_brand(brand).where(user: user).pluck(:roles).flatten.uniq
    roles == [ "employee" ] ? EMPLOYEE_INACTIVITY : STAFF_INACTIVITY
  end

  def touch_activity!
    now = Time.current
    return if last_seen_at > now - TOUCH_INTERVAL

    update_columns(last_seen_at: now, expires_at: now + self.class.inactivity_for(user, area, brand), updated_at: now)
  end

  def revoke!(reason)
    update_columns(revoked_at: Time.current, revoked_reason: reason, updated_at: Time.current) if revoked_at.nil?
  end
end
