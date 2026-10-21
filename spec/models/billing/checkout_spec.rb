require "rails_helper"

# Spec 19, RN-19-033 and RN-19-034 (D-622): the client contracts during the trial or after
# it; the first invoice opens due that day, with the PIX of the day, and the contract only
# starts when the PIX is paid. An unpaid one is voided the next day.
RSpec.describe Billing::Checkout do
  let(:company) { create(:company, name: "Metalúrgica Serra Azul") }
  let(:subscription) { trial_for(company, modules: %w[folha]) }
  let(:account) { subscription.billing_account }
  let(:plan) { create(:plan, :direct, name: "Essencial") }
  let!(:version) { create(:plan_version, plan: plan) }

  around { |example| travel_to(Time.zone.local(2026, 10, 20, 10)) { example.run } }

  before do
    Flipper.enable(FeatureFlags::BILLING)
    configure_mercado_pago
  end

  # A trial started on October 10th.
  def trial_for(owner, modules: PlanModule::MODULES)
    trial = contract_for(owner, status: "trialing", modules: modules)
    trial.update!(started_on: Date.new(2026, 10, 10), trial_ends_on: Date.new(2026, 10, 24))
    trial.items.each { |item| item.update!(starts_on: Date.new(2026, 10, 10)) }
    trial.billing_account.update!(cycle_day: 10)
    trial
  end

  def pay(invoice)
    stub_create_order
    payment = Billing::Pix.ensure_for(invoice)
    Billing::Pix.sync(mp_order(id: payment.provider_order_id, external_reference: payment.id, amount_cents: invoice.total_cents,
      status: "processed", status_detail: "accredited", paid_cents: invoice.total_cents))
  end

  describe ".start" do
    it "applies the plan and modules chosen and opens the first invoice, due today, keeping the trial" do
      invoice = described_class.start(account, plan: plan, modules: %w[ponto folha])

      expect(invoice).to have_attributes(checkout: true, status: "open", period_start: Date.new(2026, 10, 20),
        period_end: Date.new(2026, 11, 19), due_on: Date.new(2026, 10, 20), total_cents: version.minimum_monthly_cents)
      expect(invoice.lines.map(&:description)).to eq([ "Plano Essencial, mínimo mensal (nenhum colaborador ativo)" ])
      expect(subscription.reload).to have_attributes(status: "trialing", plan_version: version, activated_on: Date.new(2026, 10, 20))
      expect(subscription.modules).to contain_exactly("ponto", "folha")
      expect(account.reload.cycle_day).to eq(20)
    end

    it "takes a module off from the day before and keeps the add-ons" do
      described_class.start(account, plan: plan, modules: %w[ponto])

      expect(subscription.reload.modules).to eq(%w[ponto])
      expect(subscription.items.find_by(module: "folha").ends_on).to eq(Date.new(2026, 10, 19))
    end

    it "replaces the invoice when the client contracts again the same day" do
      first = described_class.start(account, plan: plan, modules: %w[folha])
      second = described_class.start(account, plan: plan, modules: %w[ponto folha])

      expect(first.reload).to have_attributes(status: "void", void_reason: "checkout_replaced")
      expect(second).to have_attributes(status: "open", period_start: first.period_start)
      expect(described_class.pending_invoice(account)).to eq(second)
    end

    it "starts a partner without active employees on the pre-activation fee (RN-19-035)" do
      create(:pre_activation_price, monthly_price_cents: 1_990)
      partner = create(:partner)
      trial = trial_for(partner)

      invoice = described_class.start(trial.billing_account, plan: trial.plan, modules: %w[ponto])

      expect(invoice.lines.map(&:description)).to eq([ "Mensalidade de pré-ativação" ])
      expect(invoice.total_cents).to eq(1_990)
      expect(trial.reload.activated_on).to be_nil
    end

    it "refuses a contract out of the trial and a plan not offered to it" do
      private_plan = create(:plan, :direct, private: true, billing_account: contract_for(create(:company)).billing_account)
      create(:plan_version, plan: private_plan)

      expect { described_class.start(account, plan: private_plan, modules: []) }.to raise_error(described_class::Error)
      subscription.update!(status: "active")
      expect { described_class.start(account, plan: plan, modules: []) }.to raise_error(described_class::Error)
    end
  end

  describe "payment" do
    it "starts the contract on the invoice's day when the PIX is paid, unlocking time tracking (RN-19-033)" do
      invoice = described_class.start(account, plan: plan, modules: %w[ponto folha])

      pay(invoice)

      expect(invoice.reload).to be_paid
      expect(subscription.reload).to have_attributes(status: "active", started_on: Date.new(2026, 10, 20))
      expect(CompanyModules.new(company).state("ponto")).to eq(:usable)
    end

    it "brings everything back to a trial already expired (RN-19-034)" do
      subscription.update!(status: "trial_expired")

      pay(described_class.start(account, plan: plan, modules: %w[folha]))

      expect(subscription.reload).to be_active
    end

    it "charges the overage from the contract's month on, never a trial month (D-622)" do
      travel_to(Time.zone.local(2026, 10, 2, 10))
      september_plan = create(:plan_version, plan: create(:plan, :direct, name: "Básico")).plan
      subscription.update!(started_on: Date.new(2026, 9, 20))
      UsagePeriod.create!(billing_account: account, period: "2026-09", closed_at: Time.current, ai_credits: 5_000)
      pay(described_class.start(account, plan: september_plan, modules: []))

      november = Billing::Invoicing.issue_due(subscription.reload, Date.new(2026, 10, 30)).sole
      expect(november).to have_attributes(period_start: Date.new(2026, 11, 2), usage_period: nil)
      expect(november.lines.map(&:kind)).not_to include("overage_ai")

      UsagePeriod.create!(billing_account: account, period: "2026-10", closed_at: Time.current, ai_credits: 5_000)
      december = Billing::Invoicing.issue_due(subscription.reload, Date.new(2026, 11, 29)).sole
      expect(december.usage_period).to eq("2026-10")
    end
  end

  describe ".void_unpaid" do
    it "voids the checkout's invoice not paid on its day, keeping the trial" do
      invoice = described_class.start(account, plan: plan, modules: %w[folha])

      described_class.void_unpaid(Date.new(2026, 10, 20))
      expect(invoice.reload).to be_open

      described_class.void_unpaid(Date.new(2026, 10, 21))
      expect(invoice.reload).to have_attributes(status: "void", void_reason: "checkout_unpaid")
      expect(subscription.reload).to be_trialing
    end

    it "keeps a PIX paid at the end of the day, which the daily check finds first" do
      invoice = described_class.start(account, plan: plan, modules: %w[folha])
      stub_create_order
      payment = Billing::Pix.ensure_for(invoice)
      stub_get_order(mp_order(id: payment.provider_order_id, external_reference: payment.id, amount_cents: invoice.total_cents,
        status: "processed", status_detail: "accredited", paid_cents: invoice.total_cents))
      travel_to(Time.zone.local(2026, 10, 21, 2, 30))

      Billing::ReconcileJob.perform_now

      expect(invoice.reload).to be_paid
      expect(subscription.reload).to be_active
    end
  end
end
