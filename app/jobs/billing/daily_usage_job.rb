module Billing
  # Every night, the usage of the day that ended (RN-19-020, RN-19-023, D-618): the
  # employees of each company and of each contract, the end of the partner's
  # pre-activation on the first day with an active employee (RN-19-035) and the notices of
  # 80% and 100% of the partner's band (RN-19-022). Runs again without repeating: a
  # recorded day is kept, the month is recomputed from the days, and each notice goes once
  # in the month. Does nothing while billing is off (D-610).
  class DailyUsageJob < ApplicationJob
    queue_as :default

    def perform(date = Date.yesterday)
      return unless FeatureFlags.enabled?(FeatureFlags::BILLING)

      Usage.record_through(date)
      Usage.activate_partners(date)
      Usage.alert_band(UsagePeriod.period_of(date))
    end
  end
end
