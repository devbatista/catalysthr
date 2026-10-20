module Billing
  # Closes the previous month and any earlier one still open (RN-19-023, P-19-07): records
  # the days still missing and freezes the usage, so the partner's report of the month is
  # final from day 1 (RN-19-024). Runs every day, so a day 1 the job did not run closes on
  # the next run. Running again changes nothing: a closed month takes no new days, and no
  # company counts before its contract started. Does nothing while billing is off (D-610).
  class ClosePeriodJob < ApplicationJob
    queue_as :default

    def perform(today = Date.current)
      return unless FeatureFlags.enabled?(FeatureFlags::BILLING)

      current = UsagePeriod.period_of(today)
      previous = UsagePeriod.period_of(today.prev_month)
      open = UsagePeriod.open.where(period: ...current).distinct.pluck(:period)
      (open | [ previous ]).sort.each { |period| Usage.close(period) }
    end
  end
end
