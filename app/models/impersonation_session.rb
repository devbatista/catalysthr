# Support or the superadmin seeing the system as a client's user (RN-02-080 to
# RN-02-088, D-185 to D-187). It starts at the admin area with a reason and opens the
# brand's subdomain with a one-time token (RN-02-082); it lasts at most 30 minutes and
# ends by itself (RN-02-081). Writes during it are simulated (RN-02-084).
class ImpersonationSession < ApplicationRecord
  MAX_DURATION = 30.minutes
  # The token only crosses from the admin area to the subdomain.
  TOKEN_VALIDITY = 2.minutes
  IMPERSONATORS = %w[superadmin support].freeze

  belongs_to :impersonator, class_name: "User"
  belongs_to :impersonated_user, class_name: "User"
  belongs_to :brand

  enum :ended_reason, { manual: "manual", timeout: "timeout" }, validate: { allow_nil: true }

  validates :reason, presence: true, length: { maximum: 500 }
  validate :impersonator_allowed
  validate :impersonated_user_reachable, on: :create

  # Issues the session and returns the token for the link; only its digest is kept.
  def self.issue!(impersonator:, impersonated_user:, brand:, reason:)
    token = SecureToken.generate
    session = create!(impersonator: impersonator, impersonated_user: impersonated_user, brand: brand, reason: reason,
      token_digest: SecureToken.digest(token), token_expires_at: TOKEN_VALIDITY.from_now)
    [ session, token ]
  end

  # The token works once, at the brand it was issued for, within its validity.
  def self.redeem!(token, brand:)
    return if token.blank?

    session = find_by(token_digest: SecureToken.digest(token), brand: brand)
    return if session.nil?

    redeemed = session.with_lock do
      next false unless session.started_at.nil? && session.token_expires_at.future?

      now = Time.current
      session.update!(token_digest: nil, started_at: now, expires_at: now + MAX_DURATION)
    end
    session if redeemed
  end

  def running?
    started_at.present? && ended_at.nil? && expires_at.future?
  end

  def end!(reason)
    update!(ended_at: Time.current, ended_reason: reason) if ended_at.nil?
  end

  private

  def impersonator_allowed
    errors.add(:impersonator, :not_allowed) unless impersonator&.platform_role.in?(IMPERSONATORS)
  end

  # Only a client's user, with access at the brand; never someone of the CatalystHR team
  # (RN-02-080, P-02-30).
  def impersonated_user_reachable
    return if impersonated_user.nil? || brand.nil?

    errors.add(:impersonated_user, :not_reachable) unless User.allowed_at(area: :panel, brand: brand).exists?(impersonated_user.id)
  end
end
