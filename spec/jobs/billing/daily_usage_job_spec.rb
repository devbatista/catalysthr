require "rails_helper"

# Spec 19, RN-19-020 to RN-19-023, RN-19-035 (D-612, D-618): the employees of each company
# and contract on each day, the end of the partner's pre-activation and the notices of 80%
# and 100% of the partner's band.
RSpec.describe Billing::DailyUsageJob do
  include ActiveJob::TestHelper

  let(:partner) { create(:partner, name: "Aurora Gestão de Pessoas") }
  let(:padaria) { create(:company, partner: partner, name: "Padaria Pão Quente") }
  let(:mercado) { create(:company, partner: partner, name: "Mercado Bom Preço") }
  let(:hr) { create(:user) }
  let(:subscription) { contract_for(partner) }

  around { |example| travel_to(Time.zone.local(2026, 10, 1, 9)) { example.run } }

  before do
    Flipper.enable(FeatureFlags::BILLING)
    subscription
  end

  # Someone who starts after today is registered first and then moved to the date, since the
  # form refuses a future admission.
  def hire(company, started_on: Date.new(2026, 3, 1), status: nil, ended_on: nil)
    @positions ||= {}
    position = @positions[company.id] ||= create_position(company)
    profile = register_employee(company, by: hr, position: position, started_on: [ started_on, Date.current ].min)
    ActsAsTenant.with_tenant(company) do
      employment = profile.employments.sole
      employment.update_columns(started_on: started_on) if started_on > Date.current
      employment.update!(status: status, ended_on: ended_on, termination_reason: ("dismissal" if ended_on)) if status
      employment
    end
  end

  def day(company, date)
    DailyUsage.find_by(company: company, date: date)
  end

  def month(company, period = "2026-10")
    UsagePeriod.find_by(billing_account: subscription.billing_account, company: company, period: period)
  end

  def notices
    Notification.where(notification_type: "billing.usage_threshold")
  end

  it "counts each day the employments active or on leave, and the portfolio as one contract (RN-19-020)" do
    2.times { hire(padaria) }
    hire(padaria, status: "on_leave")
    hire(padaria, status: "pending")
    hire(padaria, status: "cancelled")
    hire(mercado)
    hire(mercado, started_on: Date.new(2026, 10, 2))

    travel_to(Time.zone.local(2026, 10, 3, 1)) # records up to the day before
    2.times { described_class.perform_now }

    expect([ day(padaria, Date.new(2026, 10, 1)).active_employees, day(padaria, Date.new(2026, 10, 2)).active_employees ]).to eq([ 3, 3 ])
    expect([ day(mercado, Date.new(2026, 10, 1)).active_employees, day(mercado, Date.new(2026, 10, 2)).active_employees ]).to eq([ 1, 2 ])
    expect(DailyUsage.where(date: Date.new(2026, 10, 3))).to be_empty
    expect(DailyUsage.count).to eq(4)
    expect(month(padaria).peak_employees).to eq(3)
    expect(month(mercado).peak_employees).to eq(2)
    expect(month(nil)).to have_attributes(peak_employees: 5, ai_credits: 0, whatsapp_messages: 0, closed_at: nil)
  end

  it "counts a terminated employment up to its last day, not in the read-only period (CA-19-002)" do
    hire(padaria)
    hire(padaria, status: "terminated", ended_on: Date.new(2026, 10, 10))

    described_class.perform_now(Date.new(2026, 10, 11))
    expect(day(padaria, Date.new(2026, 10, 10)).active_employees).to eq(2)
    expect(day(padaria, Date.new(2026, 10, 11)).active_employees).to eq(1)
    expect(month(padaria).peak_employees).to eq(2)

    described_class.perform_now(Date.new(2026, 11, 30))
    expect(month(padaria, "2026-11").peak_employees).to eq(1)
  end

  it "keeps a recorded day and records the days the job did not run (RN-19-023)" do
    hire(padaria)
    described_class.perform_now(Date.new(2026, 10, 5))

    hire(padaria, started_on: Date.new(2026, 10, 1))
    described_class.perform_now(Date.new(2026, 10, 8))

    expect(day(padaria, Date.new(2026, 10, 5)).active_employees).to eq(1)
    expect(day(padaria, Date.new(2026, 10, 6)).active_employees).to eq(2)
    expect(DailyUsage.where(company: padaria).count).to eq(8)
    expect(month(padaria).peak_employees).to eq(2)
  end

  it "keeps in the month the modules the company used on at least one day (D-618)" do
    mercado
    turn_on_modules(padaria, %w[ponto])
    described_class.perform_now(Date.new(2026, 10, 1))
    turn_on_modules(padaria, [])
    described_class.perform_now(Date.new(2026, 10, 2))

    expect(day(padaria, Date.new(2026, 10, 1)).modules).to eq(%w[ponto])
    expect(day(padaria, Date.new(2026, 10, 2)).modules).to eq([])
    expect(month(padaria).modules).to eq(%w[ponto])
    expect(month(mercado).modules).to eq([])
    expect(month(nil).modules).to eq(%w[ponto])
  end

  it "records a direct company under its own contract" do
    direct = create(:company, name: "Metalúrgica Serra Azul")
    direct_subscription = contract_for(direct, modules: %w[folha])
    hire(direct)

    described_class.perform_now(Date.new(2026, 10, 1))

    expect(day(direct, Date.new(2026, 10, 1))).to have_attributes(billing_account_id: direct_subscription.billing_account_id,
      active_employees: 1, modules: %w[folha])
  end

  it "counts a company only from the contract's start, even if it was registered before" do
    direct = create(:company, name: "Metalúrgica Serra Azul")
    direct.update_columns(created_at: Time.zone.local(2026, 8, 1))
    direct_subscription = contract_for(direct)
    direct_subscription.update!(started_on: Date.new(2026, 10, 5))
    hire(direct)

    described_class.perform_now(Date.new(2026, 10, 6))

    expect(DailyUsage.where(company: direct).order(:date).pluck(:date)).to eq([ Date.new(2026, 10, 5), Date.new(2026, 10, 6) ])
  end

  it "stops counting the companies of a contract in closing (RN-05-084)" do
    hire(padaria)
    subscription.update!(status: "closing")

    described_class.perform_now(Date.new(2026, 10, 1))

    expect(DailyUsage.count).to eq(0)
  end

  it "ends the partner's pre-activation on the first day with an active employee, once (RN-19-035)" do
    subscription.update!(activated_on: nil, pre_activation_price: create(:pre_activation_price))
    padaria

    described_class.perform_now(Date.new(2026, 10, 1))
    expect(subscription.reload.activated_on).to be_nil

    employment = hire(padaria, started_on: Date.new(2026, 10, 2))
    described_class.perform_now(Date.new(2026, 10, 2))
    expect(subscription.reload.activated_on).to eq(Date.new(2026, 10, 2))

    ActsAsTenant.with_tenant(padaria) { employment.update!(status: "terminated", ended_on: Date.new(2026, 10, 2), termination_reason: "dismissal") }
    described_class.perform_now(Date.new(2026, 10, 3))
    expect(subscription.reload.activated_on).to eq(Date.new(2026, 10, 2))
  end

  describe "the band's notices (RN-19-022)" do
    let(:admin) { create(:membership, organization: partner, roles: %w[partner_admin], status: "active") }

    before do
      subscription.update!(plan_version: create(:plan_version, plan: subscription.plan, employee_limit: 5))
      subscription.billing_account.update!(responsible_user: admin.user)
    end

    it "tells the responsible at 80% and at 100%, once each in the month, without blocking anything" do
      4.times { hire(padaria) }

      perform_enqueued_jobs { 2.times { described_class.perform_now(Date.new(2026, 10, 1)) } }
      notice = notices.sole
      expect(notice).to have_attributes(recipient_membership: admin, path: "/partner/usage", mandatory: true,
        title: "Aurora Gestão de Pessoas chegou a 80% da faixa de colaboradores")
      expect(notice.body).to include("outubro de 2026", "4 colaboradores ativos", "faixa de 5", "Nada é bloqueado")
      expect(notice.deliveries.sole.channel).to eq("email")

      hire(mercado)
      hire(mercado)
      described_class.perform_now(Date.new(2026, 10, 2))
      described_class.perform_now(Date.new(2026, 10, 3))
      expect(notices.pluck(:title)).to contain_exactly("Aurora Gestão de Pessoas chegou a 80% da faixa de colaboradores",
        "Aurora Gestão de Pessoas chegou ao limite da faixa de colaboradores")
      expect(month(nil).employees_alerted_percent).to eq(100)
    end

    it "starts again in the next month, since the quota does not carry over (P-19-06)" do
      4.times { hire(padaria) }

      described_class.perform_now(Date.new(2026, 10, 31))
      described_class.perform_now(Date.new(2026, 11, 1))

      expect(notices.count).to eq(2)
    end

    it "does not tell anyone in the pre-activation, when the band is not charged (D-612)" do
      subscription.update!(activated_on: nil, pre_activation_price: create(:pre_activation_price))
      padaria

      described_class.perform_now(Date.new(2026, 10, 1))

      expect(notices).to be_empty
    end
  end

  it "does nothing while billing is off (D-610)" do
    hire(padaria)
    Flipper.disable(FeatureFlags::BILLING)

    described_class.perform_now(Date.new(2026, 10, 1))

    expect([ DailyUsage.count, UsagePeriod.count ]).to eq([ 0, 0 ])
  end
end
