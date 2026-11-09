module Dashboards
  # The HR panel's block of the contract (RN-17-030, RN-17-031, P-17-06), for the HR
  # administrator once the billing is on (D-610). In a direct company: the month's employees
  # against the plan and the billing's situation. In a partner's company: only the
  # company's own employees, never the partner's contract nor its billing. The AI credits
  # and the WhatsApp messages come with their modules (D-657).
  class Usage
    attr_reader :company, :today

    # A direct company without a contract yet has nothing to show.
    def self.shown?(ability, company)
      return false unless FeatureFlags.enabled?(FeatureFlags::BILLING) && ability.can?(:read_usage, company)

      !company.direct? || company.billing_account&.subscription.present?
    end

    def initialize(company, today)
      @company = company
      @today = today
    end

    def direct?
      company.direct?
    end

    def subscription
      company.billing_account&.subscription if direct?
    end

    def plan_name
      subscription&.plan_version_on(today)&.plan&.name
    end

    # The peak of the month so far, as the billing counts it (RN-19-020): after a transfer of
    # company, the month has a line in each contract (RN-19-003). Nil while the month has no
    # day recorded yet.
    def employees
      UsagePeriod.where(company_id: company.id, period: UsagePeriod.period_of(today)).maximum(:peak_employees)
    end
  end
end
