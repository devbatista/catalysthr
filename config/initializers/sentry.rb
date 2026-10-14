# Errors, performance and logs in Sentry (D-506, D-510, spec 20).
# No personal data leaves the app (RN-20-071, P-20-25).
if ENV["SENTRY_DSN"].present?
  Sentry.init do |config|
    config.dsn = ENV["SENTRY_DSN"]
    config.environment = Rails.env
    config.release = ENV["RAILWAY_GIT_COMMIT_SHA"]
    config.breadcrumbs_logger = [ :active_support_logger, :http_logger ]

    # Never send request bodies, cookies or user IPs.
    config.send_default_pii = false

    # 10% of traces, 100% on time-entry routes (P-20-24).
    config.traces_sampler = lambda do |context|
      path = context.dig(:env, "PATH_INFO").to_s
      path.include?("/time_entries") || path.include?("/totem") ? 1.0 : 0.1
    end

    # Send logs to Sentry Logs (D-510, RN-20-072). In sentry-ruby 7.x logs are
    # on whenever Sentry is initialized; the :logger patch forwards every Ruby
    # Logger call at or above the logger level (info in production): the
    # lograge JSON line of each request and the Sidekiq job logs.
    config.enabled_patches << :logger

    config.before_send = lambda do |event, _hint|
      SentryScrubber.scrub(event)
    end

    config.before_send_log = lambda do |log|
      log.body = SentryScrubber.mask(log.body) if log.respond_to?(:body=) && log.body.is_a?(String)
      log
    end
  end
end
