require "rails_helper"

# Spec 19, block 19g (RN-19-090, RN-19-091, D-610, D-626): the Clients block of the team's
# panel, with the cancellation risk from the sign-ins already recorded.
RSpec.describe Billing::ClientsOverview do
  around { |example| travel_to(Time.zone.local(2026, 10, 22, 10)) { example.run } }

  let(:today) { Date.new(2026, 10, 22) }
  let(:partner) { create(:partner, name: "Aurora Gestão de Pessoas") }
  let!(:brand) { create(:brand, owner: partner) }
  let(:subscription) { contract_for(partner) }
  let(:account) { subscription.billing_account }
  let!(:admin) { create(:membership, organization: partner, roles: %w[partner_admin]).user }

  def sign_in(user, at:, brand: self.brand)
    AccessEvent.create!(kind: "auth", action: "sign_in", user: user, metadata: { area: "panel", brand_id: brand.id }, created_at: at)
  end

  def row_for(account)
    described_class.new(today).rows.find { |row| row.account == account }
  end

  before { subscription.update_column(:started_on, today - 60) }

  it "shows the plan, the employees of the last recorded day, the month's usage against the band and the quotas" do
    company = create(:company, partner: partner)
    DailyUsage.create!(billing_account: account, company: company, date: today - 1, active_employees: 420)
    UsagePeriod.create!(billing_account: account, period: "2026-10", peak_employees: 450, ai_credits: 850, whatsapp_messages: 100)
    sign_in(admin, at: Time.current - 1.hour)

    row = row_for(account)
    expect(row).to have_attributes(employees: 420, band: 500, quotas: { ai_credits: 1_000, whatsapp_messages: 2_000 },
      last_sign_in_at: Time.current - 1.hour, signals: [])
    expect(row.usage).to have_attributes(peak_employees: 450, ai_credits: 850)
    expect(row).not_to be_high_risk
  end

  it "gives the direct company its quotas per employee by the month's peak" do
    direct = contract_for(create(:company), modules: [])
    UsagePeriod.create!(billing_account: direct.billing_account, period: "2026-10", peak_employees: 40)

    expect(row_for(direct.billing_account)).to have_attributes(band: nil, quotas: { ai_credits: 120, whatsapp_messages: 200 })
  end

  it "gives the reduced quotas in the trial, also to a direct company (RN-19-031)" do
    trial = contract_for(create(:company), status: "trialing")

    expect(row_for(trial.billing_account).quotas).to eq(ai_credits: 100, whatsapp_messages: 100)
  end

  it "is high risk with a 30% drop in accesses and an overdue invoice (RN-19-091)" do
    others = create_list(:user, 3)
    # Previous 30 days: 4 people on 2 days = 8; last 30 days: 2 people on 2 days = 4.
    [ 40, 50 ].each { |days| ([ admin ] + others).each { |user| sign_in(user, at: Time.current - days.days) } }
    [ 3, 10 ].each { |days| [ admin, others.first ].each { |user| sign_in(user, at: Time.current - days.days) } }
    # Twice on the same day is one person-day.
    sign_in(admin, at: Time.current - 3.days + 1.hour)
    Billing::Invoicing.issue_due(subscription, today, lead: 0).first.update!(status: "overdue")

    row = row_for(account)
    expect(row.signals).to contain_exactly(:accesses, :late_payment)
    expect(row).to be_high_risk
    expect(described_class.new(today).rows.first.account).to eq(account)
  end

  it "does not count a drop below 30% nor the CatalystHR team's sign-ins" do
    others = create_list(:user, 9)
    ([ admin ] + others).each { |user| sign_in(user, at: Time.current - 40.days) }
    # 10 to 8: a 20% drop.
    ([ admin ] + others.first(7)).each { |user| sign_in(user, at: Time.current - 2.days) }
    3.times { sign_in(create(:user, platform_role: "support"), at: Time.current - 40.days) }

    expect(row_for(account).signals).to be_empty
  end

  it "signals a module removed in the last 30 days, unless the removal was undone" do
    Billing::Invoicing.issue_due(subscription, today, lead: 0)
    Billing::ContractChanges.remove_module(subscription.reload, "ponto")
    sign_in(admin, at: Time.current)
    expect(row_for(account).signals).to eq([ :module_cancelled ])

    Billing::ContractChanges.add_module(subscription.reload, "ponto", by: admin)
    expect(row_for(account).signals).to be_empty
  end

  it "signals a module removed before it started, which the removal deletes" do
    item = subscription.items.find_by!(module: "folha")
    Billing::ContractChanges.remove_module(subscription, "folha")
    expect { item.reload }.to raise_error(ActiveRecord::RecordNotFound)
    sign_in(admin, at: Time.current)

    expect(row_for(account).signals).to eq([ :module_cancelled ])
  end

  it "signals the administrator away for 14 days, only for a contract started 14 days ago or more" do
    sign_in(admin, at: Time.current - 15.days)
    sign_in(create(:user), at: Time.current - 1.day)
    expect(row_for(account).signals).to eq([ :admin_away ])

    subscription.update_column(:started_on, today - 10)
    expect(row_for(account).signals).to be_empty
  end

  it "looks at the direct company's HR administrators at its own brand" do
    company = create(:company)
    company_brand = create(:brand, owner: company, commercial_name: "Serra Azul")
    direct = contract_for(company, modules: [])
    direct.update_column(:started_on, today - 30)
    hr = create(:membership, organization: company, roles: %w[hr_admin]).user
    sign_in(hr, at: Time.current - 2.days, brand: brand)
    expect(row_for(direct.billing_account).signals).to eq([ :admin_away ])

    sign_in(hr, at: Time.current - 2.days, brand: company_brand)
    expect(row_for(direct.billing_account)).to have_attributes(signals: [], last_sign_in_at: Time.current - 2.days)
  end

  it "leaves out the closed contracts" do
    subscription.update!(status: "closed")

    expect(described_class.new(today).rows).to be_empty
  end
end
