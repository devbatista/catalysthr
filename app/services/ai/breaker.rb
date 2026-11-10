module Ai
  # The circuit breaker of the AI queue (spec 14, RN-14-123, P-14-31): when more than half of the
  # calls to Claude fail in 5 minutes, the AI pauses for 10 minutes, the CatalystHR team is told
  # and the affected screens show the notice. It needs at least 10 calls in the window, so one
  # failure alone does not pause everything (D-670). The state lives in the cache (Solid Cache).
  module Breaker
    WINDOW = 5.minutes
    PAUSE = 10.minutes
    MINIMUM_CALLS = 10
    KEY = "ai/breaker/until".freeze

    module_function

    def open? = open_until.present?

    def open_until
      time = Rails.cache.read(KEY)
      time if time && time > Time.current
    end

    # After each call: opens when the window's failures pass half.
    def observe
      return if open?

      counts = AiRequest.where(provider: "anthropic", created_at: WINDOW.ago..).group(:status).count
      total = counts.values.sum
      failed = counts.fetch("failed", 0)
      open! if total >= MINIMUM_CALLS && failed * 2 > total
    end

    def open!
      until_time = PAUSE.from_now
      Rails.cache.write(KEY, until_time, expires_in: PAUSE)
      Rails.error.report(TransientError.new("breaker_open"), handled: true, severity: :warning, context: { until: until_time.iso8601 })
      User.where(platform_role: %w[superadmin support]).active.find_each do |user|
        Notifications.notify!("platform.ai_breaker_open", user: user, area: "admin", path: "/ai",
          dedup_key: "platform.ai_breaker_open/#{until_time.to_i}", until: I18n.l(until_time, format: "%H:%M"))
      end
    end
  end
end
