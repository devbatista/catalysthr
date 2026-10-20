require "rails_helper"

# Spec 19, RN-19-023 and RN-19-024 (P-19-07, P-19-08): on day 1 the previous month is
# closed with every day recorded, and it no longer changes.
RSpec.describe Billing::ClosePeriodJob do
  let(:partner) { create(:partner) }
  let!(:padaria) { create(:company, partner: partner, name: "Padaria Pão Quente") }
  let(:subscription) { contract_for(partner) }

  around { |example| travel_to(Time.zone.local(2026, 9, 1, 9)) { example.run } }

  before do
    Flipper.enable(FeatureFlags::BILLING)
    subscription
  end

  def period(name)
    UsagePeriod.find_by(company: padaria, period: name)
  end

  it "records the missing days and closes the previous month on day 1, once" do
    Billing::DailyUsageJob.perform_now(Date.new(2026, 9, 10))

    described_class.perform_now(Date.new(2026, 10, 1))
    closed_at = period("2026-09").closed_at

    expect(DailyUsage.where(company: padaria, date: Date.new(2026, 9, 1)..Date.new(2026, 9, 30)).count).to eq(30)
    expect(UsagePeriod.where(period: "2026-09").pluck(:closed_at)).to all(be_present)
    expect(period("2026-10")).to be_nil

    described_class.perform_now(Date.new(2026, 10, 2))
    expect(period("2026-09").closed_at).to eq(closed_at)
  end

  it "keeps a closed month as it was" do
    Billing::DailyUsageJob.perform_now(Date.new(2026, 9, 10))
    described_class.perform_now(Date.new(2026, 10, 1))
    UsagePeriod.where(period: "2026-09").update_all(peak_employees: 7)

    Billing::Usage.refresh("2026-09")

    expect(period("2026-09").peak_employees).to eq(7)
  end

  it "does nothing without a contract that counts" do
    subscription.update!(status: "closed")

    described_class.perform_now(Date.new(2026, 10, 1))

    expect([ DailyUsage.count, UsagePeriod.count ]).to eq([ 0, 0 ])
  end

  it "never fills a closed month, not even for a contract that started after it" do
    Billing::DailyUsageJob.perform_now(Date.new(2026, 9, 30))
    described_class.perform_now(Date.new(2026, 10, 1))

    travel_to(Time.zone.local(2026, 10, 2, 9))
    direct = create(:company, name: "Metalúrgica Serra Azul")
    direct.update_columns(created_at: Time.zone.local(2026, 8, 1))
    contract_for(direct)
    described_class.perform_now(Date.new(2026, 10, 3))
    Billing::Usage.close("2026-09")

    expect(DailyUsage.where(company: direct)).to be_empty
    expect(UsagePeriod.where(company: direct)).to be_empty
  end

  it "closes the months whose day 1 the job missed" do
    Billing::DailyUsageJob.perform_now(Date.new(2026, 9, 10))

    described_class.perform_now(Date.new(2026, 11, 3))

    expect(UsagePeriod.where(company: padaria).order(:period).pluck(:period, :closed_at))
      .to match([ [ "2026-09", be_present ], [ "2026-10", be_present ] ])
    expect(DailyUsage.where(company: padaria).maximum(:date)).to eq(Date.new(2026, 10, 31))
  end

  it "does nothing while billing is off (D-610)" do
    Flipper.disable(FeatureFlags::BILLING)

    described_class.perform_now(Date.new(2026, 10, 1))

    expect(UsagePeriod.count).to eq(0)
  end
end
