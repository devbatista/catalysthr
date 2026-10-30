require "sidekiq/api"

# The detailed health check, /up/deep (RN-20-074, D-627): the database, Redis and the delay
# of each Sidekiq queue, for the external monitors. Outside ApplicationController, like
# /up: no brand, session or tenant, on any host (HostResolver). The token goes in the
# Authorization header ("Bearer <token>"); without HEALTH_CHECK_TOKEN set, the page does
# not exist. The answer carries no data from the clients and no error details. The ClamAV
# is checked once CLAMAV_HOST is set, so production does not fail before the service is
# created (D-638, D-640).
class HealthChecksController < ActionController::Base
  # The queues of spec 20 (RN-20-011), the `time` one in its own worker.
  QUEUES = %w[time critical esocial notifications default ai reports imports].freeze
  # The `time` queue late by more than 2 minutes is critical (RN-20-075); the others only
  # show their delay.
  MAX_LATENCY = { "time" => 120 }.freeze

  def show
    return head :not_found unless authorized?

    response.headers["Cache-Control"] = "no-store"
    checks = { database: database, redis: redis }
    checks[:clamav] = clamav if Antivirus::Clamd.configured?
    checks[:queues] = queues if checks[:redis] == "ok"
    healthy = checks.values_at(:database, :redis).all?("ok") && checks.fetch(:clamav, "ok") == "ok" &&
      checks.fetch(:queues, {}).none? { |_, queue| queue[:late] }
    render json: { status: healthy ? "ok" : "fail", checks: checks }, status: healthy ? :ok : :service_unavailable
  end

  private

  def authorized?
    token = ENV["HEALTH_CHECK_TOKEN"].to_s
    given = request.authorization.to_s.delete_prefix("Bearer ")
    token.present? && ActiveSupport::SecurityUtils.secure_compare(given, token)
  end

  def database
    ActiveRecord::Base.connection.select_value("SELECT 1") == 1 ? "ok" : "fail"
  rescue StandardError
    "fail"
  end

  def redis
    Sidekiq.redis { |connection| connection.call("PING") } == "PONG" ? "ok" : "fail"
  rescue StandardError
    "fail"
  end

  def clamav
    Antivirus::Clamd.new.ping? ? "ok" : "fail"
  end

  def queues
    QUEUES.to_h do |name|
      queue = Sidekiq::Queue.new(name)
      latency = queue.latency.round
      [ name, { size: queue.size, latency_seconds: latency, late: MAX_LATENCY.key?(name) && latency > MAX_LATENCY[name] } ]
    end
  end
end
