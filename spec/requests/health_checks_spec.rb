require "rails_helper"

# Spec 20, block 20b (RN-20-074, RN-20-075, D-627): the detailed health check, with a token.
RSpec.describe "Detailed health check", type: :request do
  around do |example|
    previous = ENV["HEALTH_CHECK_TOKEN"]
    ENV["HEALTH_CHECK_TOKEN"] = "token-do-monitor"
    example.run
  ensure
    ENV["HEALTH_CHECK_TOKEN"] = previous
  end

  def check(token: "token-do-monitor", host: "health.painel.catalysthr.com.br")
    host! host
    get "/up/deep", headers: ({ "Authorization" => "Bearer #{token}" } if token)
  end

  def late_queue(name, latency)
    allow(Sidekiq::Queue).to receive(:new).and_wrap_original do |original, queue|
      queue == name ? instance_double(Sidekiq::Queue, size: 42, latency: latency) : original.call(queue)
    end
  end

  it "answers the database, Redis and the queues on any host, without the sign-in feature" do
    check

    expect(response).to have_http_status(:ok)
    expect(response.headers["Cache-Control"]).to include("no-store")
    body = response.parsed_body
    expect(body).to include("status" => "ok", "checks" => include("database" => "ok", "redis" => "ok"))
    expect(body.dig("checks", "queues").keys).to eq(HealthChecksController::QUEUES)
    expect(body.dig("checks", "queues", "time")).to include("late" => false)
  end

  it "fails when the time queue is late by more than 2 minutes (RN-20-075)" do
    late_queue("time", 121.4)

    check(host: "admin.catalysthr.com.br")

    expect(response).to have_http_status(:service_unavailable)
    expect(response.parsed_body).to include("status" => "fail")
    expect(response.parsed_body.dig("checks", "queues", "time")).to eq("size" => 42, "latency_seconds" => 121, "late" => true)
  end

  it "only shows the delay of the other queues" do
    late_queue("reports", 900)

    check

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.dig("checks", "queues", "reports")).to include("latency_seconds" => 900, "late" => false)
  end

  it "fails without telling why when the database does not answer" do
    allow(ActiveRecord::Base.connection).to receive(:select_value).and_raise(ActiveRecord::ConnectionNotEstablished, "host=10.0.0.5")

    check

    expect(response).to have_http_status(:service_unavailable)
    expect(response.parsed_body.dig("checks", "database")).to eq("fail")
    expect(response.body).not_to include("10.0.0.5")
  end

  it "skips the queues when Redis does not answer" do
    allow(Sidekiq).to receive(:redis).and_raise(RedisClient::CannotConnectError)

    check

    expect(response).to have_http_status(:service_unavailable)
    expect(response.parsed_body["checks"]).to eq("database" => "ok", "redis" => "fail")
  end

  it "does not exist without the right token" do
    check(token: nil)
    expect(response).to have_http_status(:not_found)

    check(token: "outro")
    expect(response).to have_http_status(:not_found)

    ENV["HEALTH_CHECK_TOKEN"] = ""
    check(token: "")
    expect(response).to have_http_status(:not_found)
  end
end
