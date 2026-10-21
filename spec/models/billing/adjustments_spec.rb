require "rails_helper"

# Spec 19, RN-19-070 and RN-19-071 (CA-19-009, D-621): manual adjustments of the next
# invoices, with the superadmin's approval when the finance team goes above 20% of the
# next invoice's preview.
RSpec.describe Billing::Adjustments do
  include ActiveJob::TestHelper

  let(:finance) { create(:user, platform_role: "finance", name: "Fernanda Financeiro") }
  let!(:superadmin) { create(:user, platform_role: "superadmin", name: "Paulo Lima") }
  let(:partner) { create(:partner, name: "Aurora Gestão de Pessoas") }
  let(:subscription) { contract_for(partner) }
  let(:account) { subscription.billing_account }

  around { |example| travel_to(Time.zone.local(2026, 10, 1, 9)) { example.run } }

  before do
    Flipper.enable(FeatureFlags::BILLING)
    Billing::Invoicing.issue_due(subscription, Date.current, lead: 0)
  end

  def launch(by = finance, **attributes)
    described_class.launch(account, { reason: "Falha nossa no ponto em 03/10", cycles: 1 }.merge(attributes), by: by)
  end

  def issue(today)
    Billing::Invoicing.issue_due(subscription.reload, today).sole
  end

  def adjustment_lines(invoice)
    invoice.lines.select(&:kind_adjustment?).map { |line| [ line.description, line.total_cents ] }
  end

  # September's usage, with the band in force then (D-612).
  def closed_month(**usage)
    subscription.update!(activated_on: Date.new(2026, 9, 1), started_on: Date.new(2026, 9, 1))
    UsagePeriod.create!(billing_account: account, period: "2026-09", closed_at: Time.current, peak_employees: 0, **usage)
  end

  describe "approval (RN-19-071)" do
    it "holds a finance team's adjustment above 20% for the superadmin, who is told, and applies it once approved (CA-19-009)" do
      adjustment = perform_enqueued_jobs { launch(kind: "discount", percent: "25") }

      expect(adjustment).to be_pending
      notice = Notification.where(notification_type: "platform.adjustment_pending").sole
      expect(notice).to have_attributes(recipient_user: superadmin, area: "admin", path: "/adjustments",
        title: "Ajuste de Aurora Gestão de Pessoas aguardando aprovação")
      expect(notice.body).to include("Fernanda Financeiro lançou desconto de 25%", "acima de 20% da próxima fatura")
      expect(notice.deliveries.sole.channel).to eq("email")
      expect(adjustment_lines(issue(Date.new(2026, 10, 29)))).to be_empty

      described_class.approve(adjustment, by: superadmin)

      expect(adjustment.reload).to have_attributes(status: "approved", approved_by: superadmin)
      expect(adjustment_lines(issue(Date.new(2026, 11, 28)))).to eq([ [ "Desconto de 25%", -62_500 ] ])
    end

    it "approves at once up to 20% of the preview, and anything the superadmin launches" do
      expect(launch(kind: "discount", value: "400,00")).to have_attributes(status: "approved", approved_by: finance)
      expect(launch(kind: "discount", value: "600,00")).to be_pending
      expect(launch(superadmin, kind: "credit", value: "3.000,00")).to have_attributes(status: "approved", approved_by: superadmin)
    end

    it "compares a waiver with the overage it takes off the preview" do
      closed_month(peak_employees: 530)

      expect(launch(kind: "overage_waiver", overage_scope: "employees")).to be_approved
    end
  end

  it "takes the percent off every line before the adjustments, overage included" do
    closed_month(peak_employees: 530)
    launch(superadmin, kind: "discount", percent: "10")

    # 10% of 2.500,00 plus 30 employees above the band at 3,00.
    expect(adjustment_lines(issue(Date.new(2026, 10, 29)))).to eq([ [ "Desconto de 10%", -25_900 ] ])
  end

  it "spreads a discount over the cycles chosen, one invoice each" do
    launch(kind: "discount", value: "100,00", cycles: 2)

    expect(adjustment_lines(issue(Date.new(2026, 10, 29)))).to eq([ [ "Desconto (1 de 2)", -10_000 ] ])
    expect(adjustment_lines(issue(Date.new(2026, 11, 28)))).to eq([ [ "Desconto (2 de 2)", -10_000 ] ])
    expect(adjustment_lines(issue(Date.new(2026, 12, 29)))).to be_empty
  end

  it "carries the rest of a credit to the next invoices, never below zero" do
    launch(superadmin, kind: "credit", value: "3.000,00")

    november = issue(Date.new(2026, 10, 29))
    expect(november.total_cents).to eq(0)
    expect(adjustment_lines(november)).to eq([ [ "Crédito", -250_000 ] ])
    expect(adjustment_lines(issue(Date.new(2026, 11, 28)))).to eq([ [ "Crédito", -50_000 ] ])
    expect(adjustment_lines(issue(Date.new(2026, 12, 29)))).to be_empty
  end

  it "waives only the overage chosen, on the next invoice" do
    closed_month(peak_employees: 530, ai_credits: 1_200)
    launch(kind: "overage_waiver", overage_scope: "employees")

    expect(adjustment_lines(issue(Date.new(2026, 10, 29)))).to eq([ [ "Isenção do excedente de colaboradores", -9_000 ] ])
    expect(adjustment_lines(issue(Date.new(2026, 11, 28)))).to be_empty
  end

  it "takes the discounts before the credits, so the credit keeps what is left" do
    launch(superadmin, kind: "credit", value: "3.000,00")
    launch(superadmin, kind: "discount", percent: "50")

    expect(adjustment_lines(issue(Date.new(2026, 10, 29)))).to eq([ [ "Desconto de 50%", -125_000 ], [ "Crédito", -125_000 ] ])
    expect(adjustment_lines(issue(Date.new(2026, 11, 28)))).to eq([ [ "Crédito", -175_000 ] ])
  end

  it "cancels an adjustment not yet applied, and never one already in an invoice" do
    pending_one = launch(kind: "discount", percent: "25")
    applied = launch(superadmin, kind: "discount", percent: "5")
    issue(Date.new(2026, 10, 29))

    expect(described_class.cancel(pending_one, by: finance)).to be_truthy
    expect(described_class.cancel(applied.reload, by: finance)).to be(false)
    expect(pending_one.reload).to have_attributes(status: "cancelled", cancelled_by: finance)
    expect(described_class.approve(pending_one, by: superadmin)).to be(false)
  end

  it "requires a reason and the amount of each kind" do
    expect(launch(kind: "discount", reason: "").errors[:reason]).to be_present
    expect(launch(kind: "discount", value: "10,00", percent: "5").errors[:base]).to include("Informe o valor ou o percentual do desconto, não os dois")
    expect(launch(kind: "credit").errors[:value_cents]).to be_present
    expect(launch(kind: "overage_waiver", overage_scope: "all", value: "1,00").errors[:base]).to be_present
    expect(launch(kind: "credit", value: "10,00", cycles: 2).errors[:cycles]).to include("só o desconto vale por mais de uma fatura")
    expect(BillingAdjustment.count).to eq(0)
  end
end
