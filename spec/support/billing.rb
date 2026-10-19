# Contracts for the specs (spec 19): a subscription with modules for a direct company or
# a partner, and the modules a partner turned on for a company (D-616).
module BillingHelpers
  def contract_for(owner, modules: PlanModule::MODULES, status: "active")
    plan = owner.is_a?(Partner) ? create(:plan) : create(:plan, :direct)
    version = create(:plan_version, plan: plan)
    account = BillingAccount.create!(owner: owner, cycle_day: BillingAccount.cycle_day_for(Date.current))
    trial = status.in?(CompanyModules::TRIAL_STATUSES)
    subscription = Subscription.create!(billing_account: account, plan_version: version, created_by: version.created_by,
      status: status, started_on: Date.current, trial_ends_on: (Date.current + Subscription::TRIAL_DAYS if trial),
      activated_on: (Date.current unless trial))
    modules.each { |code| subscription.items.create!(kind: "module", module: code, starts_on: Date.current) }
    subscription
  end

  def turn_on_modules(company, modules = PlanModule::MODULES)
    CompanyModuleSetting.apply(company, modules, by: create(:user))
  end
end

RSpec.configure do |config|
  config.include BillingHelpers
end
