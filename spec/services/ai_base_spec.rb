require "rails_helper"

# Spec 14, block 14a (D-670): the call to Claude inside the zero data retention, the record
# without the content (CA-14-014), the credits by contract (RN-14-110 to RN-14-113), the daily
# cap (RN-14-114, CA-14-012), the failures and the circuit breaker (RN-14-120 to RN-14-123), and
# the 80% and 100% notices (RN-14-112, CA-14-011).
RSpec.describe "AI base" do
  include ActiveJob::TestHelper

  let(:partner) { create(:partner, name: "Aurora Gestão de Pessoas") }
  let(:company) { create(:company, partner: partner, name: "Padaria Pão Quente") }
  let(:subscription) { contract_for(partner) }
  let(:schema) do
    { type: "object", additionalProperties: false, required: %w[kind fields],
      properties: { kind: { type: "string", enum: %w[rg cnh] },
                    fields: { type: "array", items: { type: "object", additionalProperties: false, required: %w[key value],
                                                      properties: { key: { type: "string" }, value: { type: %w[string null] } } } } } }
  end
  let(:answer) { { "kind" => "rg", "fields" => [ { "key" => "name", "value" => "Ana Lima" } ] } }
  let(:pdf) { Base64.strict_encode64("%PDF-1.4 fictício") }

  around { |example| travel_to(Time.zone.local(2026, 11, 10, 10)) { example.run } }

  before do
    Flipper.enable(FeatureFlags::AI)
    configure_anthropic
    subscription
  end

  def call(feature: "document_extraction", subject: nil)
    Ai::Call.run(company: company, feature: feature, prompt_version: "test-1", subject: subject) do |client|
      client.structured(system: "Instruções fixas.", schema: schema, max_tokens: 2_000,
        content: [ { type: "document", source: { type: "base64", media_type: "application/pdf", data: pdf } },
                   { type: "text", text: "Leia o documento." } ])
    end
  end

  def usage(company_id)
    UsagePeriod.find_by(billing_account: subscription.billing_account, company_id: company_id, period: "2026-11")
  end

  it "sends the PDF inside the call with the answer's schema, and records the call without its content (RN-14-003, CA-14-014)" do
    stub_claude(answer, usage: { input_tokens: 10_000, output_tokens: 1_000 })

    result = call
    expect(result.data).to eq(answer)

    expect(WebMock).to(have_requested(:post, AnthropicHelpers::MESSAGES_URL).with do |request|
      body = JSON.parse(request.body)
      document = body.dig("messages", 0, "content", 0)
      body["model"] == "claude-sonnet-5-5" && document.dig("source", "type") == "base64" &&
        body.dig("output_config", "format", "type") == "json_schema" && body.dig("output_config", "format", "schema", "required") == %w[kind fields] &&
        request.headers["Authorization"] == "Bearer sk-ant-test" && !request.headers.key?("Anthropic-Beta")
    end)

    request = AiRequest.sole
    expect(request).to have_attributes(company: company, feature: "document_extraction", status: "succeeded", model: "claude-sonnet-5-5",
      prompt_version: "test-1", input_tokens: 10_000, output_tokens: 1_000, credits: 1, cost_usd_micros: 30_000)
    expect(request.attributes.values.map(&:to_s).join).not_to include("Ana Lima", "PDF")
  end

  it "charges the function's credits to the contract and to the month's usage, with the weight in force (RN-14-110, RN-14-111)" do
    AiCreditWeight.create!(feature: "document_extraction", credits: 3, valid_from: Date.new(2026, 11, 11))
    stub_claude(answer)

    call
    expect(AiCreditEntry.sole).to have_attributes(billing_account: subscription.billing_account, company: company, credits: 1, period: "2026-11")
    expect([ usage(company.id).ai_credits, usage(nil).ai_credits ]).to eq([ 1, 1 ])

    travel_to(Time.zone.local(2026, 11, 11, 10))
    call
    expect([ usage(company.id).ai_credits, usage(nil).ai_credits ]).to eq([ 4, 4 ])
    expect(Ai::DailyCap.of(company).used_credits).to eq(3)
  end

  it "uses no credits when the call fails, and tells transient failures from invalid answers (RN-14-113, RN-14-120)" do
    stub_claude(status: 529)
    expect { call }.to raise_error(Ai::TransientError, "http_529")

    stub_claude(status: 400)
    expect { call }.to raise_error(Ai::InvalidResponse, "http_400")

    stub_claude(answer, stop_reason: "refusal")
    expect { call }.to raise_error(Ai::InvalidResponse, "refusal")

    stub_claude({ "kind" => "passport", "fields" => [] })
    expect { call }.to raise_error(Ai::InvalidResponse, /schema_mismatch/)

    stub_claude(text: "não é JSON")
    expect { call }.to raise_error(Ai::InvalidResponse, "invalid_json")

    stub_request(:post, AnthropicHelpers::MESSAGES_URL).to_timeout
    expect { call }.to raise_error(Ai::TransientError)

    expect(AiRequest.pluck(:status).uniq).to eq(%w[failed])
    expect(AiRequest.pluck(:error_code)).to include("http_529", "http_400", "refusal", "schema_mismatch", "invalid_json")
    expect(AiRequest.sum(:credits)).to eq(0)
    expect(AiCreditEntry.count).to eq(0)
    expect(usage(nil)).to be_nil
  end

  it "says when the AI may run, and sends everything else to the manual flow (RN-14-010, RN-14-132)" do
    expect(Ai::Availability.check(company, "document_extraction")).to eq(:available)

    ActsAsTenant.with_tenant(company) { CompanyAiSetting.create!(feature: "document_extraction", enabled: false) }
    expect(Ai::Availability.check(company, "document_extraction")).to eq(:disabled)
    expect(Ai::Availability.check(company, "batch_classification")).to eq(:available)

    allow(Simulation).to receive(:active?).and_return(true)
    expect(Ai::Availability.check(company, "batch_classification")).to eq(:simulation)
    allow(Simulation).to receive(:active?).and_call_original

    Rails.configuration.x.anthropic_api_key = nil
    expect(Ai::Availability.check(company, "batch_classification")).to eq(:unavailable)
    configure_anthropic
    Flipper.disable(FeatureFlags::AI)
    expect(Ai::Availability.check(company, "batch_classification")).to eq(:unavailable)
  end

  describe "daily cap (RN-14-114, D-395)" do
    let!(:hr) { create(:membership, organization: company, roles: %w[hr_admin], status: "active") }
    let!(:support) { create(:user, platform_role: "support") }
    let!(:finance) { create(:user, platform_role: "finance") }

    it "starts at 200 credits, or 5 times the daily average of the last 30 days" do
      expect(Ai::DailyCap.computed(company)).to eq(200)

      AiCreditEntry.create!(company: company, period: "2026-10", credits: 1_500, created_at: Time.zone.local(2026, 10, 20, 10))
      AiCreditEntry.create!(company: company, period: "2026-11", credits: 900, created_at: Time.zone.local(2026, 11, 10, 8))
      expect(Ai::DailyCap.computed(company)).to eq(250)

      company.update!(ai_daily_cap_credits: 40)
      expect(Ai::DailyCap.computed(company)).to eq(40)
      expect(Ai::DailyCap.computed(company, override: false)).to eq(250)
    end

    it "pauses the company's AI on reaching the cap, tells the team and the HR administrator, and the support releases it (CA-14-012)" do
      company.update!(ai_daily_cap_credits: 2)
      stub_claude(answer)

      call
      expect(Ai::Availability.check(company, "document_extraction")).to eq(:available)
      call
      expect(Ai::Availability.check(company, "document_extraction")).to eq(:paused)
      expect(Notification.where(notification_type: "platform.ai_daily_cap_reached").map(&:recipient_user)).to eq([ support ])
      expect(Notification.where(notification_type: "ai.daily_cap_reached").map(&:recipient_user)).to eq([ hr.user ])

      cap = Ai::DailyCap.of(company)
      Ai::DailyCap.release!(cap, by: support)
      expect(cap.reload).to have_attributes(released_by: support, paused?: false)
      call
      expect(Ai::Availability.check(company, "document_extraction")).to eq(:available)
      expect(Notification.where(notification_type: "ai.daily_cap_reached").count).to eq(1)

      travel_to(Time.zone.local(2026, 11, 11, 0, 5))
      expect(Ai::DailyCap.of(company)).to have_attributes(date: Date.new(2026, 11, 11), used_credits: 0, paused?: false)
    end

    it "ends the pause when the team raises the cap above what was used" do
      company.update!(ai_daily_cap_credits: 1)
      stub_claude(answer)
      call
      expect(Ai::DailyCap.paused?(company)).to be(true)

      Ai::DailyCap.set!(company, 10)
      expect(Ai::DailyCap.of(company)).to have_attributes(cap_credits: 10, paused?: false)
    end
  end

  describe "circuit breaker (RN-14-123)" do
    let(:cache) { ActiveSupport::Cache::MemoryStore.new }
    let!(:superadmin) { create(:user, platform_role: "superadmin") }

    before { allow(Rails).to receive(:cache).and_return(cache) }

    it "pauses the AI for 10 minutes when more than half of at least 10 calls fail in 5 minutes" do
      stub_claude(answer)
      4.times { call }
      stub_claude(status: 503)
      5.times { expect { call }.to raise_error(Ai::TransientError) }
      expect(Ai::Breaker.open?).to be(false)

      expect { call }.to raise_error(Ai::TransientError)
      expect(Ai::Breaker.open_until).to eq(Time.zone.local(2026, 11, 10, 10, 10))
      expect(Ai::Availability.check(company, "document_extraction")).to eq(:breaker)
      expect(Notification.where(notification_type: "platform.ai_breaker_open").map(&:recipient_user)).to eq([ superadmin ])

      travel_to(Time.zone.local(2026, 11, 10, 10, 11))
      expect(Ai::Breaker.open?).to be(false)
    end
  end

  describe "new tries of the jobs (RN-14-120, RN-14-121)" do
    let(:job_class) do
      Class.new(ApplicationJob) do
        include Ai::Retries

        def self.name = "AiTestJob"
        cattr_accessor :failures, default: []
        cattr_accessor :error_class

        def perform = raise(error_class, "stubbed")
        def ai_failed!(error) = failures << [ error.class, executions ]
      end
    end

    before { stub_const("AiTestJob", job_class) }

    it "tries a transient failure 3 more times, after 1, 5 and 15 minutes, and then sends it to the manual flow" do
      AiTestJob.failures = []
      AiTestJob.error_class = Ai::TransientError
      AiTestJob.perform_later
      waits = []
      4.times do
        job = enqueued_jobs.shift
        waits << (job[:at] && (job[:at] - Time.current.to_f).round)
        ActiveJob::Base.execute(job)
      end
      expect(waits.compact).to eq([ 60, 300, 900 ])
      expect(AiTestJob.failures).to eq([ [ Ai::TransientError, 4 ] ])
    end

    it "tries an invalid answer once more" do
      AiTestJob.failures = []
      AiTestJob.error_class = Ai::InvalidResponse
      perform_enqueued_jobs { AiTestJob.perform_later }
      expect(AiTestJob.failures).to eq([ [ Ai::InvalidResponse, 2 ] ])
    end
  end

  describe "80% and 100% notices (RN-14-112, CA-14-011)" do
    let!(:admin) { create(:membership, organization: partner, roles: %w[partner_admin], status: "active") }

    def notices = Notification.where(notification_type: "billing.usage_threshold")

    it "tells the partner's administrator once at each threshold, without blocking anything" do
      quota = subscription.monthly_quotas(0)[:ai_credits]
      Ai::Credits.add_to_usage(subscription.billing_account, company, "2026-11", (quota * 0.8).ceil)

      2.times { Ai::UsageAlertsJob.perform_now }
      expect(notices.map { |notice| [ notice.recipient_user, notice.title ] }).to eq([ [ admin.user, "Aurora Gestão de Pessoas chegou a 80% dos créditos de IA do mês" ] ])
      expect(Ai::Availability.check(company, "document_extraction")).to eq(:available)

      Ai::Credits.add_to_usage(subscription.billing_account, company, "2026-11", quota)
      Ai::UsageAlertsJob.perform_now
      expect(notices.map(&:title)).to contain_exactly(a_string_including("80% dos créditos"), a_string_including("limite dos créditos de IA"))
    end
  end
end
