# The support entering a direct company to set it up or to help (D-581, P-03-02, D-127):
# it acts there as a consultant, an HR analyst of all units with every module the
# company contracted (D-593), with real writes. It starts at the admin area with a reason
# and opens the company's subdomain with a one-time token, like the impersonate
# (RN-02-082). It lasts while the support's session does, 30 minutes of inactivity
# (RN-02-050). The support keeps no membership (P-02-01).
class SupportAccess < ApplicationRecord
  TOKEN_VALIDITY = ImpersonationSession::TOKEN_VALIDITY

  belongs_to :support_user, class_name: "User"
  belongs_to :company
  belongs_to :brand

  enum :ended_reason, { manual: "manual", timeout: "timeout" }, validate: { allow_nil: true }

  validates :reason, presence: true, length: { maximum: 500 }
  validate :support_only
  validate :direct_company, on: :create

  def self.issue!(support_user:, company:, reason:)
    token = SecureToken.generate
    access = create!(support_user: support_user, company: company, brand: company.subdomain_brand, reason: reason,
      token_digest: SecureToken.digest(token), token_expires_at: TOKEN_VALIDITY.from_now)
    [ access, token ]
  end

  # The token works once, at the company's brand, within its validity.
  def self.redeem!(token, brand:)
    return if token.blank?

    access = find_by(token_digest: SecureToken.digest(token), brand: brand)
    return if access.nil?

    redeemed = access.with_lock do
      next false unless access.started_at.nil? && access.token_expires_at.future?

      access.update!(token_digest: nil, started_at: Time.current)
    end
    access if redeemed
  end

  def running?
    started_at.present? && ended_at.nil?
  end

  def end!(reason)
    update!(ended_at: Time.current, ended_reason: reason) if ended_at.nil?
  end

  private

  def support_only
    errors.add(:support_user, :not_support) unless support_user&.support?
  end

  # In a partner's company the support only sees by impersonate (P-03-02).
  def direct_company
    return if company.nil?

    errors.add(:company, :not_direct) unless company.direct? && company.subdomain_brand&.active_subdomain
  end
end
