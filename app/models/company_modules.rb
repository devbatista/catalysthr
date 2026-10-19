# The modules a company may use, from its contract (P-03-12, RN-19-012, D-616): the
# direct company's own, or the partner's, for the modules the partner turned on for the
# company. Payroll brings eSocial (D-111). During the trial, and after it ends without a
# contract, time tracking and eSocial do not work (RN-19-031): time tracking shows as
# available after the contract (CA-19-003), and payroll works without closing a
# period, which its spec enforces. A closed contract has no modules. The releasable
# modules outside the contract are part of the core (RN-19-011). While billing is off
# (D-610), every module stays as it was before the contracts.
class CompanyModules
  # The releasable modules each contracted module brings.
  RELEASABLE = { "ponto" => %w[ponto], "folha" => %w[folha esocial] }.freeze
  CONTRACT_RELEASABLE = RELEASABLE.values.flatten.freeze
  TRIAL_STATUSES = %w[trialing trial_expired].freeze
  # Not in a trial: what works in the trial (RN-19-031).
  TRIAL_RELEASABLE = %w[folha].freeze

  attr_reader :company

  def initialize(company)
    @company = company
  end

  def subscription
    return @subscription if defined?(@subscription)

    owner = company.direct? ? company : company.partner
    @subscription = owner&.billing_account&.subscription
  end

  def billing?
    return @billing if defined?(@billing)

    @billing = FeatureFlags.enabled?(FeatureFlags::BILLING)
  end

  def trial?
    billing? && subscription.present? && subscription.status.in?(TRIAL_STATUSES)
  end

  # The contracted modules the company uses, by code (PlanModule::MODULES).
  def contracted
    @contracted ||= if !billing?
      PlanModule::MODULES
    elsif subscription.nil? || subscription.closed?
      []
    elsif company.direct?
      subscription.modules
    else
      subscription.modules & CompanyModuleSetting.where(company: company, enabled: true).pluck(:module)
    end
  end

  # :usable, :after_contract or nil, for a contracted module's code.
  def state(code)
    return unless contracted.include?(code)
    return :usable unless trial?

    code == "ponto" ? :after_contract : :usable
  end

  # The releasable modules (Membership::RELEASABLE_MODULES) the contract allows.
  def releasable
    @releasable ||= begin
      from_contract = contracted.flat_map { |code| RELEASABLE.fetch(code) }
      from_contract &= TRIAL_RELEASABLE if trial?
      (Membership::RELEASABLE_MODULES - CONTRACT_RELEASABLE) + from_contract
    end
  end
end
