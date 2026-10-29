module Holidays
  # Once a year, the next year's national holidays from BrasilAPI, for the team to review
  # (P-06-20, P-11-06, D-638); the admin also runs it for a chosen year. Idempotent: a date
  # already imported is not proposed again. When BrasilAPI fails, the job raises and
  # Sidekiq tries again, so the failure reaches Sentry instead of passing in silence.
  class ImportNationalJob < ApplicationJob
    queue_as :default

    REVIEWERS = %w[superadmin support].freeze

    def perform(year = Date.current.year + 1)
      created = ImportNational.call(year)
      return if created.empty?

      User.where(platform_role: REVIEWERS).active.find_each do |user|
        Notifications.notify!("platform.holidays_review", user: user, area: "admin", path: "/holidays?year=#{year}",
          dedup_key: "platform.holidays_review/#{year}", year: year, count: created.size)
      end
    end
  end
end
