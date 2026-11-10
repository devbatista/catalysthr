module Ai
  # The company's daily safety cap (spec 14, RN-14-114, D-395, P-14-27): the largest of 5 times
  # the company's daily average of credits in the last 30 days and 200 credits, unless the
  # CatalystHR team set another for the company. The day is Brasília's, so the pause lasts until
  # midnight there. Reaching the cap pauses the company's AI and tells the superadmins, the
  # support and the company's HR administrators.
  module DailyCap
    MINIMUM = 200
    MULTIPLIER = 5
    WINDOW_DAYS = 30
    TIME_ZONE = "America/Sao_Paulo".freeze

    module_function

    def today = Time.current.in_time_zone(TIME_ZONE).to_date

    # The day's row, created with the cap computed when the day's first call comes.
    def of(company, date = today)
      AiDailyCap.find_or_create_by!(company: company, date: date) { |cap| cap.cap_credits = computed(company, date) }
    rescue ActiveRecord::RecordNotUnique
      AiDailyCap.find_by!(company: company, date: date)
    end

    # The team's cap for the company or, without one (or asked without), the computed one.
    def computed(company, date = today, override: true)
      return company.ai_daily_cap_credits if override && company.ai_daily_cap_credits

      start = date - WINDOW_DAYS
      used = AiCreditEntry.where(company: company, kind: "usage", created_at: day_range(start, date - 1)).sum(:credits)
      [ (used * MULTIPLIER / WINDOW_DAYS.to_f).ceil, MINIMUM ].max
    end

    def paused?(company)
      AiDailyCap.where(company: company, date: today).where.not(paused_at: nil).where(released_at: nil).exists?
    end

    # Adds the credits of a call; the call that reaches the cap pauses the rest of the day.
    def add!(company, credits)
      cap = of(company)
      cap.with_lock do
        cap.used_credits += credits
        reached = cap.used_credits >= cap.cap_credits && cap.paused_at.nil? && !cap.released?
        cap.paused_at = Time.current if reached
        cap.save!
        notify(cap) if reached
      end
    end

    # The superadmin or the support releases the day (RN-14-114).
    def release!(cap, by:)
      cap.with_lock { cap.update!(released_at: Time.current, released_by: by) if cap.paused? }
    end

    # A new cap from the team also changes today's, so the pause ends if the new cap is above
    # what was used.
    def set!(company, credits)
      company.update!(ai_daily_cap_credits: credits)
      cap = AiDailyCap.find_by(company: company, date: today)
      return unless cap

      cap.with_lock do
        cap.cap_credits = computed(company)
        cap.paused_at = nil if cap.paused? && cap.used_credits < cap.cap_credits
        cap.save!
      end
    end

    def day_range(first, last)
      zone = ActiveSupport::TimeZone[TIME_ZONE]
      zone.local(first.year, first.month, first.day)...zone.local(last.year, last.month, last.day).tomorrow
    end

    def notify(cap)
      company = cap.company
      params = { name: company.name, cap: cap.cap_credits }
      User.where(platform_role: %w[superadmin support]).active.find_each do |user|
        Notifications.notify!("platform.ai_daily_cap_reached", user: user, area: "admin", path: "/ai/companies/#{company.id}",
          subject: cap, dedup_key: "platform.ai_daily_cap_reached/#{cap.id}", **params)
      end
      ActsAsTenant.with_tenant(company) do
        Membership.where(organization: company, status: "active").with_role("hr_admin").includes(:user).find_each do |membership|
          Notifications.notify!("ai.daily_cap_reached", user: membership.user, membership: membership, path: "/settings/ai/edit",
            subject: cap, dedup_key: "ai.daily_cap_reached/#{cap.id}", **params)
        end
      end
    end
  end
end
