# Sidekiq queues and concurrency (spec 20, RN-20-011, P-20-05).
#
# Two processes in production:
# - worker-time: only the `time` queue (time entries, receipts, AFD), so it never
#   waits behind other jobs (P-10-26). Start with SIDEKIQ_ROLE=time.
# - worker: every other queue, plus sidekiq-cron.
redis_config = { url: ENV.fetch("REDIS_URL", "redis://localhost:6390/0") }

Sidekiq.configure_client do |config|
  config.redis = redis_config
end

Sidekiq.configure_server do |config|
  config.redis = redis_config

  if ENV["SIDEKIQ_ROLE"] == "time"
    config.queues = %w[time]
  else
    # Strict priority inside the default capsule: earlier queues run first.
    config.queues = %w[critical esocial notifications default]

    config.capsule("ai") do |cap|
      cap.concurrency = 4
      cap.queues = %w[ai]
    end

    config.capsule("reports") do |cap|
      cap.concurrency = 2
      cap.queues = %w[reports]
    end

    config.capsule("imports") do |cap|
      cap.concurrency = 1
      cap.queues = %w[imports]
    end

    schedule_file = Rails.root.join("config/schedule.yml")
    if File.exist?(schedule_file)
      schedule = YAML.load_file(schedule_file) || {}
      Sidekiq::Cron::Job.load_from_hash!(schedule, source: "schedule") if schedule.any?
    end
  end
end
