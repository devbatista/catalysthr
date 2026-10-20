module Billing
  # The lines of a contract's invoice for the cycle starting on a date (RN-19-040, D-612,
  # D-619), with the prices of the contract's plan version and add-on versions (D-611):
  # - partner: the band's monthly price and the modules, or only the pre-activation fee
  #   before the first active employee; the add-ons; and the overage of the last closed
  #   month: employees above the band, AI credits and WhatsApp messages above the quotas;
  # - direct company: the plan per active employee, with the monthly minimum on the plan's
  #   line only, and the modules per employee; the add-ons; and the overage of the AI and
  #   WhatsApp quotas, which are per employee. The employees are the peak of the last closed
  #   month, or those active on the day when there is none.
  # The prorations of plan changes and the manual adjustments come with block 19d-2.
  class InvoiceLines
    Line = Data.define(:kind, :description, :quantity, :unit_cents) do
      def total_cents
        quantity * unit_cents
      end
    end

    attr_reader :subscription, :cycle_start, :usage, :employees

    # usage: the contract's closed month to charge (UsagePeriod), or nil.
    # employees: the direct company's employees to charge.
    def initialize(subscription, cycle_start, usage:, employees: nil)
      @subscription = subscription
      @cycle_start = cycle_start
      @usage = usage
      @employees = employees
    end

    def lines
      subscription.billing_account.partner? ? partner_lines : direct_lines
    end

    private

    def version
      subscription.plan_version
    end

    def partner_lines
      lines = if subscription.pre_activation?
        [ line(:plan, t("pre_activation"), 1, subscription.pre_activation_price.monthly_price_cents) ]
      else
        [ line(:plan, t("plan", plan: version.plan.name), 1, version.monthly_price_cents) ] +
          modules.map { |code| line(:module, t("module", module: module_name(code)), 1, version.plan_module(code).price_cents) }
      end
      lines + add_on_lines + partner_overage
    end

    def direct_lines
      count = employees.to_i
      plan = if count * version.price_per_employee_cents < version.minimum_monthly_cents
        line(:plan, t("plan_minimum", plan: version.plan.name, count: count), 1, version.minimum_monthly_cents)
      else
        line(:plan, t("plan_per_employee", plan: version.plan.name), count, version.price_per_employee_cents)
      end
      module_lines = count.zero? ? [] : modules.map do |code|
        line(:module, t("module_per_employee", module: module_name(code)), count, version.plan_module(code).price_cents)
      end
      return [ plan, *module_lines, *add_on_lines ] if usage.nil?

      [ plan, *module_lines, *add_on_lines,
        *quota_overage(version.ai_credits_per_employee * usage.peak_employees, version.whatsapp_messages_per_employee * usage.peak_employees) ]
    end

    def add_on_lines
      subscription.add_on_prices(cycle_start).map do |price|
        line(:add_on, I18n.t("add_ons.names.#{price.add_on.code}"), 1, price.monthly_price_cents)
      end
    end

    # The band and the plan's quotas count from the activation; before it, in the trial or
    # the pre-activation, the reduced quotas (RN-19-031, D-612).
    def partner_overage
      return [] if usage.nil?

      activated = subscription.activated_on.present? && subscription.activated_on <= UsagePeriod.days(usage.period).last
      lines = []
      excess = usage.peak_employees - version.employee_limit
      if activated && excess.positive?
        lines << line(:overage_employees,
          t("overage_employees", month: month, peak: delimited(usage.peak_employees), limit: delimited(version.employee_limit)),
          excess, version.overage_per_employee_cents)
      end
      quotas = activated ? [ version.ai_credits, version.whatsapp_messages ] : [ Subscription::REDUCED_AI_CREDITS, Subscription::REDUCED_WHATSAPP_MESSAGES ]
      lines + quota_overage(*quotas)
    end

    def quota_overage(ai_quota, whatsapp_quota)
      [
        [ :overage_ai, usage.ai_credits, ai_quota, version.ai_credit_overage_cents ],
        [ :overage_whatsapp, usage.whatsapp_messages, whatsapp_quota, version.whatsapp_overage_cents ]
      ].filter_map do |kind, used, quota, price|
        excess = used - quota
        line(kind, t(kind, month: month, used: delimited(used), quota: delimited(quota)), excess, price) if excess.positive?
      end
    end

    def modules
      subscription.modules(cycle_start).sort
    end

    def month
      I18n.l(UsagePeriod.days(usage.period).first, format: :month_year)
    end

    # "1.200", as the descriptions are read in Portuguese.
    def delimited(number)
      ActiveSupport::NumberHelper.number_to_delimited(number, locale: :"pt-BR")
    end

    def module_name(code)
      I18n.t("modules.#{code}")
    end

    def line(kind, description, quantity, unit_cents)
      Line.new(kind: kind.to_s, description: description, quantity: quantity, unit_cents: unit_cents)
    end

    def t(key, **params)
      I18n.t("billing.invoice_lines.#{key}", **params)
    end
  end
end
