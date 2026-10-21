require "rails_helper"

# Spec 19, RN-19-050 to RN-19-053 (D-116, D-493, D-495, D-624): the dunning schedule,
# counted from the oldest invoice not paid, with the notices, the read only and the closing.
RSpec.describe Billing::Dunning do
  let(:partner) { create(:partner, name: "Aurora Gestão de Pessoas") }
  let(:subscription) { contract_for(partner) }
  let(:account) { subscription.billing_account }
  let!(:responsible) { create(:membership, organization: partner, roles: %w[partner_admin]) }
  let!(:client_hr) { create(:membership, organization: create(:company, partner: partner, name: "Metalúrgica Serra Azul"), roles: %w[hr_admin]) }
  let!(:invoice) { Billing::Invoicing.issue_due(subscription, Date.current, lead: 0).sole }

  around { |example| travel_to(Time.zone.local(2026, 10, 1, 3)) { example.run } }

  before do
    Flipper.enable(FeatureFlags::BILLING)
    account.update!(responsible_user: responsible.user)
  end

  def run_on(day)
    described_class.run(Date.new(2026, 10, 1) + day)
  end

  def notices(code)
    Notification.where(notification_type: code).order(:created_at)
  end

  it "follows the schedule from the due date: notices, read only on day 15 and closing on day 30 (RN-19-050)" do
    run_on(0)
    expect(subscription.reload).to be_active

    run_on(1)
    expect(invoice.reload).to be_overdue
    expect(subscription.reload).to be_past_due
    expect(notices("billing.overdue").sole).to have_attributes(recipient_user: responsible.user, path: "/partner/invoices/#{invoice.id}",
      title: "A fatura 000001 de Aurora Gestão de Pessoas venceu")
    expect(notices("billing.overdue").sole.body).to include("R$ 2.500,00", "01/10/2026", "16/10/2026")

    run_on(5)
    run_on(10)
    expect(notices("billing.overdue").pluck(:title).last).to eq("Aurora Gestão de Pessoas entra em somente leitura em 5 dias")

    run_on(15)
    expect(subscription.reload).to be_read_only
    expect(notices("billing.overdue").pluck(:title).last).to eq("Aurora Gestão de Pessoas está em somente leitura")
    portfolio = notices("billing.partner_read_only").sole
    expect(portfolio).to have_attributes(recipient_user: client_hr.user, title: "Acesso limitado por pendência com Aurora Gestão de Pessoas")
    expect(portfolio.body).not_to include("R$")

    run_on(25)
    expect(notices("billing.contract_closing").sole.title).to eq("O contrato de Aurora Gestão de Pessoas entra em encerramento em 5 dias")

    run_on(30)
    expect(subscription.reload).to have_attributes(status: "closing", closing_on: Date.new(2026, 10, 31))
    expect(notices("billing.contract_closing").count).to eq(2)
    expect(notices("billing.overdue").count).to eq(4)
  end

  it "repeats no notice when it runs again, and tells only the latest step after days it missed" do
    2.times { run_on(1) }
    expect(notices("billing.overdue").count).to eq(1)

    run_on(12)
    expect(notices("billing.overdue").pluck(:title)).to eq([ "A fatura 000001 de Aurora Gestão de Pessoas venceu",
      "Aurora Gestão de Pessoas entra em somente leitura em 5 dias" ])
  end

  it "brings the contract back as the late invoices are paid, but not from closing (RN-19-053)" do
    run_on(16)
    expect(subscription.reload).to be_read_only

    invoice.update!(status: "paid", paid_at: Time.current)
    run_on(17)
    expect(subscription.reload).to be_active

    subscription.update!(status: "closing", closing_on: Date.new(2026, 10, 31))
    run_on(40)
    expect(subscription.reload).to be_closing
  end

  describe ".reactivate" do
    let(:superadmin) { create(:user, platform_role: "superadmin") }

    before do
      run_on(30)
      travel_to(Time.zone.local(2026, 11, 10, 9))
    end

    it "reactivates a contract in closing once the invoices are paid, with the reason (RN-19-053)" do
      expect(described_class.reactivate(subscription, by: superadmin, reason: "Pagou por TED")).to eq(:past_due)

      invoice.update!(status: "paid", paid_at: Time.current)
      expect(described_class.reactivate(subscription, by: superadmin, reason: " ")).to eq(:without_reason)
      expect(described_class.reactivate(subscription, by: superadmin, reason: "Pagou por TED")).to eq(:reactivated)
      expect(subscription.reload).to have_attributes(status: "active", reactivated_by: superadmin, reactivation_reason: "Pagou por TED",
        closing_on: nil)
    end

    it "keeps the 90 days" do
      invoice.update!(status: "paid", paid_at: Time.current)
      travel_to(Time.zone.local(2027, 1, 30, 9))

      expect(described_class.reactivate(subscription, by: superadmin, reason: "Pagou")).to eq(:too_late)
    end
  end

  it "issues an invoice the adjustments take to zero as paid, out of the schedule (D-624)" do
    described_class.run(Date.new(2026, 10, 2))
    Billing::Adjustments.launch(account, { kind: "credit", value: "3.000,00", reason: "Acordo comercial" }, by: create(:user, platform_role: "superadmin"))
    invoice.update!(status: "paid", paid_at: Time.current)

    november = Billing::Invoicing.issue_due(subscription.reload, Date.new(2026, 10, 29)).sole

    expect(november).to have_attributes(total_cents: 0, status: "paid", paid_at: Time.current)
    expect(november.payments).to be_empty
  end
end
