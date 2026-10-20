require "rails_helper"

# Spec 19, RN-19-040 and RN-19-041 (CA-19-001, D-612, D-619): the invoice of each cycle,
# issued 3 days before it starts and due on its first day, with every line: the plan or the
# pre-activation fee, the modules, the add-ons and the overage of the last closed month.
RSpec.describe Billing::Invoicing do
  include ActiveJob::TestHelper

  let(:partner) { create(:partner, name: "Aurora Gestão de Pessoas") }
  let(:admin) { create(:membership, organization: partner, roles: %w[partner_admin], status: "active") }
  let(:subscription) do
    contract_for(partner).tap { |subscription| subscription.billing_account.update!(responsible_user: admin.user) }
  end
  let(:account) { subscription.billing_account }

  around { |example| travel_to(Time.zone.local(2026, 10, 15, 9)) { example.run } }

  before { Flipper.enable(FeatureFlags::BILLING) }

  def issue(today = Date.current, lead: 0)
    Billing::Invoicing.issue_due(subscription.reload, today, lead: lead)
  end

  def lines(invoice)
    invoice.lines.map { |line| [ line.kind, line.description, line.quantity, line.unit_cents, line.total_cents ] }
  end

  def closed_month(peak:, ai: 0, whatsapp: 0, period: "2026-10", target: account)
    UsagePeriod.create!(billing_account: target, period: period, peak_employees: peak, ai_credits: ai, whatsapp_messages: whatsapp,
      closed_at: Time.current)
  end

  def add_on(subscription)
    price = create(:add_on_price, monthly_price_cents: 9_900)
    subscription.items.create!(kind: "add_on", add_on_price: price, starts_on: Date.current)
  end

  describe "a partner under contract" do
    it "charges the band, the modules and the add-ons of the cycle that starts, due on its first day" do
      add_on(subscription)

      invoice = perform_enqueued_jobs { issue.sole }

      expect(invoice).to have_attributes(number: 1, period_start: Date.new(2026, 10, 15), period_end: Date.new(2026, 11, 14),
        due_on: Date.new(2026, 10, 15), status: "open", total_cents: 259_900, usage_period: nil)
      expect(lines(invoice)).to eq([
        [ "plan", "Plano #{subscription.plan.name}", 1, 150_000, 150_000 ],
        [ "module", "Módulo Folha", 1, 60_000, 60_000 ],
        [ "module", "Módulo Ponto", 1, 40_000, 40_000 ],
        [ "add_on", "Número próprio de WhatsApp", 1, 9_900, 9_900 ]
      ])
      notice = Notification.where(notification_type: "billing.invoice_issued").sole
      expect(notice).to have_attributes(recipient_membership: admin, path: "/partner/invoices/#{invoice.id}",
        title: "Fatura 000001 de Aurora Gestão de Pessoas: R$ 2.599,00")
      expect(notice.body).to include("15/10/2026 a 14/11/2026", "vence em 15/10/2026")
      expect(notice.deliveries.sole.channel).to eq("email")
    end

    it "charges the employees above the band in the last closed month (CA-19-001)" do
      issue
      closed_month(peak: 530)

      invoice = issue(Date.new(2026, 11, 12), lead: 3).sole

      expect(invoice).to have_attributes(period_start: Date.new(2026, 11, 15), usage_period: "2026-10")
      expect(lines(invoice).last).to eq([ "overage_employees",
        "Colaboradores acima da faixa em outubro de 2026 (pico de 530 para a faixa de 500)", 30, 300, 9_000 ])
    end

    it "charges the AI credits and the WhatsApp messages above the quotas" do
      issue
      closed_month(peak: 10, ai: 1_200, whatsapp: 2_001)

      invoice = issue(Date.new(2026, 11, 12), lead: 3).sole

      expect(lines(invoice).last(2)).to eq([
        [ "overage_ai", "Créditos de IA acima da cota em outubro de 2026 (1.200 de 1.000)", 200, 50, 10_000 ],
        [ "overage_whatsapp", "Mensagens de WhatsApp acima da cota em outubro de 2026 (2.001 de 2.000)", 1, 35, 35 ]
      ])
    end

    it "charges a closed month once" do
      issue
      closed_month(peak: 530)
      issue(Date.new(2026, 11, 12), lead: 3)

      invoice = issue(Date.new(2026, 12, 12), lead: 3).sole

      expect(invoice.usage_period).to be_nil
      expect(invoice.lines.map(&:kind)).not_to include("overage_employees")
    end
  end

  describe "a partner in the pre-activation (RN-19-035, D-612)" do
    before do
      subscription.update!(activated_on: nil, pre_activation_price: create(:pre_activation_price, monthly_price_cents: 1_990))
      add_on(subscription)
    end

    it "charges only the pre-activation fee and the add-ons" do
      expect(lines(issue.sole)).to eq([
        [ "plan", "Mensalidade de pré-ativação", 1, 1_990, 1_990 ],
        [ "add_on", "Número próprio de WhatsApp", 1, 9_900, 9_900 ]
      ])
    end

    it "charges the overage above the reduced quotas, without the band" do
      issue
      closed_month(peak: 0, ai: 150)

      expect(lines(issue(Date.new(2026, 11, 12), lead: 3).sole).last).to eq(
        [ "overage_ai", "Créditos de IA acima da cota em outubro de 2026 (150 de 100)", 50, 50, 2_500 ])
    end
  end

  describe "a direct company" do
    let(:company) { create(:company, name: "Metalúrgica Serra Azul") }
    let(:subscription) { contract_for(company, modules: %w[folha]) }

    it "charges the monthly minimum on the first invoice, with no employee yet, and no module" do
      expect(lines(issue.sole)).to eq([
        [ "plan", "Plano #{subscription.plan.name}, mínimo mensal (nenhum colaborador ativo)", 1, 30_000, 30_000 ]
      ])
    end

    it "charges the plan and the modules per employee of the last closed month" do
      issue
      closed_month(peak: 30, ai: 100)

      expect(lines(issue(Date.new(2026, 11, 12), lead: 3).sole)).to eq([
        [ "plan", "Plano #{subscription.plan.name}, por colaborador ativo", 30, 1_200, 36_000 ],
        [ "module", "Módulo Folha, por colaborador ativo", 30, 60_000, 1_800_000 ],
        [ "overage_ai", "Créditos de IA acima da cota em outubro de 2026 (100 de 90)", 10, 50, 500 ]
      ])
    end

    it "applies the minimum to the plan's line only (D-619)" do
      issue
      closed_month(peak: 10)

      expect(lines(issue(Date.new(2026, 11, 12), lead: 3).sole)).to eq([
        [ "plan", "Plano #{subscription.plan.name}, mínimo mensal (10 colaboradores ativos)", 1, 30_000, 30_000 ],
        [ "module", "Módulo Folha, por colaborador ativo", 10, 60_000, 600_000 ]
      ])
    end
  end

  describe Billing::GenerateInvoicesJob do
    it "issues the cycle 3 days before it starts, once, numbering the invoices in sequence" do
      issue
      other = contract_for(create(:company, name: "Metalúrgica Serra Azul"))

      Billing::GenerateInvoicesJob.perform_now(Date.new(2026, 11, 11))
      expect(account.invoices.count).to eq(1)

      2.times { Billing::GenerateInvoicesJob.perform_now(Date.new(2026, 11, 12)) }

      expect(account.invoices.order(:number).pluck(:period_start)).to eq([ Date.new(2026, 10, 15), Date.new(2026, 11, 15) ])
      expect(Invoice.order(:number).pluck(:number, :billing_account_id)).to eq([
        [ 1, account.id ], [ 2, other.billing_account_id ], [ 3, account.id ], [ 4, other.billing_account_id ]
      ])
    end

    it "issues the cycles the job missed" do
      issue

      Billing::GenerateInvoicesJob.perform_now(Date.new(2026, 12, 20))

      expect(account.invoices.order(:period_start).pluck(:period_start)).to eq(
        [ Date.new(2026, 10, 15), Date.new(2026, 11, 15), Date.new(2026, 12, 15) ])
    end

    it "closes the previous month before charging its overage" do
      issue
      UsagePeriod.create!(billing_account: account, period: "2026-10", peak_employees: 520)

      Billing::GenerateInvoicesJob.perform_now(Date.new(2026, 11, 12))

      expect(UsagePeriod.find_by(billing_account: account, period: "2026-10").closed_at).to be_present
      expect(account.invoices.find_by(period_start: Date.new(2026, 11, 15)).usage_period).to eq("2026-10")
    end

    it "charges neither the trial nor a contract in closing" do
      subscription.update!(status: "trialing", trial_ends_on: Date.new(2026, 10, 29))
      contract_for(create(:company), status: "closing")

      Billing::GenerateInvoicesJob.perform_now(Date.new(2026, 10, 15))

      expect(Invoice.count).to eq(0)
    end

    it "does nothing while billing is off (D-610)" do
      subscription
      Flipper.disable(FeatureFlags::BILLING)

      Billing::GenerateInvoicesJob.perform_now(Date.new(2026, 10, 15))

      expect(Invoice.count).to eq(0)
    end
  end
end
