# The read only of a contract and all its companies (RN-19-034, RN-19-051, D-116, D-494,
# D-613, D-624): in arrears from day 15 (`read_only`), in closing, closed, and the trial
# that ended without a contract. Nothing new is created or changed on the panel; the
# person's own account, paying and contracting stay open. Time tracking and the eSocial
# events already generated keep working when their specs arrive (RN-19-051). While billing
# is off (D-610), nothing is locked.
class ContractLock
  STATUSES = %w[read_only closing closed trial_expired].freeze

  attr_reader :subscription, :organization

  # The lock of a company (its own contract, or its partner's) or of a partner, if any.
  def self.for(organization)
    return if organization.nil? || !FeatureFlags.enabled?(FeatureFlags::BILLING)

    owner = organization.is_a?(Company) && organization.partner_id ? organization.partner : organization
    subscription = owner.billing_account&.subscription
    new(subscription, organization) if subscription&.status.in?(STATUSES)
  end

  def initialize(subscription, organization)
    @subscription = subscription
    @organization = organization
  end

  # :overdue, :closing or :trial_expired.
  def reason
    case subscription.status
    when "read_only" then :overdue
    when "trial_expired" then :trial_expired
    else :closing
    end
  end

  def account
    subscription.billing_account
  end

  # A company of a partner's portfolio, which sees only the partner's name (RN-19-052).
  def portfolio_company?
    organization.is_a?(Company) && organization.partner_id.present?
  end
end
