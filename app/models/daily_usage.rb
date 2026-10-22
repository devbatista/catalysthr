# The employees a company had active or on leave on a day, under the contract that billed
# it that day, with the modules it used (RN-19-020, RN-19-023, D-618). Written once a day
# by Billing::DailyUsageJob and never changed: a transfer of company splits the month by
# the days of each contract (RN-19-003). Not tenant-scoped: the job and the partner's panel
# have no current company, and every query names the contract or the company.
class DailyUsage < ApplicationRecord
  belongs_to :billing_account
  belongs_to :company

  # The employees of each contract on its last recorded day, by contract id: what the team's
  # panel shows and prices the direct companies' recurring revenue with (D-626).
  def self.latest_totals(account_ids)
    where(billing_account_id: account_ids)
      .where("daily_usages.date = (SELECT MAX(latest.date) FROM daily_usages latest WHERE latest.billing_account_id = daily_usages.billing_account_id)")
      .group(:billing_account_id).sum(:active_employees)
  end

  def readonly?
    persisted? || super
  end
end
