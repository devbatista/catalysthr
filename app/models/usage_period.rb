# The usage of a month (spec 19, section 7), for each company of a contract and for the
# whole contract (company_id null): the peak of employees, the modules used on at least one
# day of the month (D-618), the AI credits and the WhatsApp messages (RN-19-020 to
# RN-19-024). Refreshed every day from the days already recorded, and closed on day 1 of
# the next month (P-19-07). A quota does not carry over to the next month (P-19-06). Not
# tenant-scoped, like DailyUsage.
class UsagePeriod < ApplicationRecord
  FORMAT = "%Y-%m"

  belongs_to :billing_account
  belongs_to :company, optional: true

  scope :totals, -> { where(company_id: nil) }
  scope :of_companies, -> { where.not(company_id: nil) }
  scope :open, -> { where(closed_at: nil) }

  # "2026-10" for any day of October 2026.
  def self.period_of(date)
    date.strftime(FORMAT)
  end

  def self.days(period)
    Date.strptime(period, FORMAT).all_month
  end

  def closed?
    closed_at.present?
  end
end
