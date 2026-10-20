module Billing
  # Every night, the plan versions scheduled for the day take effect (RN-19-014, RN-19-061),
  # then the invoices of the cycles that start in up to 3 days are issued (RN-19-041, D-619),
  # after the usage of the previous month is closed, so the overage is final. A cycle the job
  # missed is issued on the next run. Runs again without repeating: each cycle has one
  # invoice. Does nothing while billing is off (D-610).
  class GenerateInvoicesJob < ApplicationJob
    queue_as :default

    def perform(today = Date.current)
      return unless FeatureFlags.enabled?(FeatureFlags::BILLING)

      ContractChanges.apply_scheduled(today)
      previous = UsagePeriod.period_of(today.prev_month)
      Usage.close(previous) if UsagePeriod.open.exists?(period: previous)
      Subscription.where(status: Invoicing::BILLABLE)
        .includes(:pre_activation_price, { plan_version: %i[plan plan_modules] }, { items: { add_on_price: :add_on } }, :billing_account)
        .find_each { |subscription| Invoicing.issue_due(subscription, today) }
    end
  end
end
