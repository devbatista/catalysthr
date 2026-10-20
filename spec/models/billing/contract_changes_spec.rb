require "rails_helper"

# Spec 19, RN-19-014, RN-19-060 and RN-19-061 (CA-19-005, D-612, D-620): changes to a
# contract. An increase takes effect at once with the proportional difference on the next
# invoice; a reduction takes effect after the last day invoiced; a price migration from the
# first cycle 30 days ahead.
RSpec.describe Billing::ContractChanges do
  include ActiveJob::TestHelper

  let(:finance) { create(:user, platform_role: "finance") }
  let(:partner) { create(:partner, name: "Aurora Gestão de Pessoas") }
  let(:admin) { create(:membership, organization: partner, roles: %w[partner_admin], status: "active") }
  let(:subscription) do
    contract_for(partner, modules: %w[folha]).tap { |subscription| subscription.billing_account.update!(responsible_user: admin.user) }
  end
  let(:account) { subscription.billing_account }

  around { |example| travel_to(Time.zone.local(2026, 10, 1, 9)) { example.run } }

  before { Flipper.enable(FeatureFlags::BILLING) }

  def issue(today, lead: 3)
    Billing::Invoicing.issue_due(subscription.reload, today, lead: lead)
  end

  def version_of(plan_name, **prices)
    plan = create(:plan, name: plan_name)
    create(:plan_version, plan: plan, **prices)
  end

  def kinds_and_totals(invoice)
    invoice.lines.map { |line| [ line.kind, line.total_cents ] }
  end

  describe "a module contracted in the middle of the cycle (CA-19-005)" do
    it "charges the days left of the cycle from the day of the change, plus the whole next month" do
      issue(Date.current, lead: 0)

      travel_to(Time.zone.local(2026, 10, 10, 9))
      result = described_class.add_module(subscription.reload, "ponto", by: finance)

      expect(result.proration).to have_attributes(kind: "module", total_cents: 28_387, effective_on: Date.new(2026, 10, 10),
        description: "Proporcional do módulo Ponto, a partir de 10/10/2026", created_by: finance)
      expect(partner.reload.contracted_modules).to contain_exactly("folha", "ponto")

      next_invoice = issue(Date.new(2026, 10, 29)).sole
      expect(kinds_and_totals(next_invoice)).to eq([ [ "plan", 150_000 ], [ "module", 60_000 ], [ "module", 40_000 ], [ "proration", 28_387 ] ])
      expect(issue(Date.new(2026, 11, 28)).sole.lines.map(&:kind)).not_to include("proration")
    end

    it "also charges the next cycle already invoiced" do
      issue(Date.current, lead: 0)
      issue(Date.new(2026, 10, 29))

      travel_to(Time.zone.local(2026, 10, 30, 9))
      result = described_class.add_module(subscription.reload, "ponto", by: finance)

      # 2 of 31 days in October and the whole of November.
      expect(result.proration.total_cents).to eq(42_581)
    end

    it "keeps a module whose removal was scheduled, with nothing to prorate" do
      issue(Date.current, lead: 0)
      described_class.remove_module(subscription.reload, "folha")

      result = described_class.add_module(subscription.reload, "folha", by: finance)

      expect(result.proration).to be_nil
      expect(subscription.reload.items.sole.ends_on).to be_nil
    end
  end

  describe "a module or add-on removed (RN-19-061)" do
    it "ends on the last day invoiced and leaves the next invoice" do
      issue(Date.current, lead: 0)

      travel_to(Time.zone.local(2026, 10, 10, 9))
      result = described_class.remove_module(subscription.reload, "folha")

      expect(result.effective_on).to eq(Date.new(2026, 11, 1))
      expect(partner.reload.contracted_modules).to eq(%w[folha])
      expect(issue(Date.new(2026, 10, 29)).sole.lines.map(&:kind)).to eq(%w[plan])
      travel_to(Time.zone.local(2026, 11, 1, 9))
      expect(partner.reload.contracted_modules).to be_empty
    end

    it "removes at once a module of a contract with no invoice yet" do
      subscription.update!(status: "trialing", trial_ends_on: Date.new(2026, 10, 15))

      described_class.remove_module(subscription.reload, "folha")

      expect(subscription.reload.items).to be_empty
    end
  end

  it "charges the days left of an add-on contracted in the middle of the cycle" do
    issue(Date.current, lead: 0)
    add_on = create(:add_on_price, monthly_price_cents: 9_900).add_on

    travel_to(Time.zone.local(2026, 10, 10, 9))
    result = described_class.add_add_on(subscription.reload, add_on, by: finance)

    expect(result.proration).to have_attributes(kind: "add_on", total_cents: 7_026,
      description: "Proporcional de Número próprio de WhatsApp, a partir de 10/10/2026")
  end

  describe "a change of plan (RN-19-060, RN-19-061)" do
    before { issue(Date.current, lead: 0) }

    it "takes an increase at once, with the proportional difference" do
      bigger = version_of("Até 1.000 colaboradores", monthly_price_cents: 200_000, employee_limit: 1_000)

      travel_to(Time.zone.local(2026, 10, 16, 9))
      result = described_class.change_plan(subscription.reload, bigger, by: finance)

      expect(subscription.reload.plan_version).to eq(bigger)
      # 50.000 more for 16 of 31 days.
      expect(result.proration).to have_attributes(kind: "plan", total_cents: 25_806)
    end

    it "schedules a reduction for the next cycle, which the invoice and the job then apply" do
      smaller = version_of("Até 200 colaboradores", monthly_price_cents: 100_000, employee_limit: 200)

      result = described_class.change_plan(subscription.reload, smaller, by: finance)

      expect(result).to have_attributes(effective_on: Date.new(2026, 11, 1), proration: nil)
      expect(subscription.reload).to have_attributes(plan_version: subscription.plan_version, next_plan_version: smaller,
        next_plan_version_reason: "reduction")
      expect(kinds_and_totals(issue(Date.new(2026, 10, 29)).sole).first).to eq([ "plan", 100_000 ])

      Billing::GenerateInvoicesJob.perform_now(Date.new(2026, 11, 1))
      expect(subscription.reload).to have_attributes(plan_version: smaller, next_plan_version: nil)
    end

    it "decides by what the month costs: a lower price per employee with a higher minimum is an increase" do
      company = create(:company, name: "Metalúrgica Serra Azul")
      direct = contract_for(company, modules: [])
      Billing::Invoicing.issue_due(direct, Date.current, lead: 0)
      higher_minimum = create(:plan_version, plan: create(:plan, :direct, name: "Direta com mínimo maior"),
        price_per_employee_cents: 1_000, minimum_monthly_cents: 50_000)

      result = described_class.change_plan(direct.reload, higher_minimum, by: finance)

      expect(direct.reload.plan_version).to eq(higher_minimum)
      # 20.000 more for the 31 days of October.
      expect(result.proration.total_cents).to eq(20_000)
    end

    it "lets the team undo a scheduled reduction" do
      described_class.change_plan(subscription.reload, version_of("Até 200 colaboradores", monthly_price_cents: 100_000), by: finance)

      described_class.cancel_scheduled(subscription.reload)

      expect(subscription.reload.next_plan_version).to be_nil
    end
  end

  describe "the partner's activation (D-612)" do
    it "charges the band and the modules instead of the pre-activation fee for the days left" do
      subscription.update!(activated_on: nil, pre_activation_price: create(:pre_activation_price, monthly_price_cents: 1_990))
      issue(Date.current, lead: 0)
      company = create(:company, partner: partner)
      position = create_position(company)
      register_employee(company, by: finance, position: position, started_on: Date.new(2026, 10, 1))
      ActsAsTenant.with_tenant(company) { Employment.update_all(started_on: Date.new(2026, 10, 11)) }

      Billing::DailyUsageJob.perform_now(Date.new(2026, 10, 11))

      proration = account.prorations.sole
      # (1.500,00 + 600,00 - 19,90) for 21 of 31 days.
      expect(proration).to have_attributes(kind: "activation", total_cents: 140_910, created_by: nil,
        description: "Proporcional da ativação em 11/10/2026: faixa e módulos no lugar da pré-ativação")
    end
  end

  describe "a price migration (RN-19-014)" do
    let!(:newer) { create(:plan_version, plan: subscription.plan, monthly_price_cents: 180_000) }

    it "moves the contract from the first cycle 30 days ahead, with the notice, once" do
      result = perform_enqueued_jobs { described_class.migrate_price(subscription.reload) }

      expect(result.effective_on).to eq(Date.new(2026, 11, 1))
      expect(subscription.reload).to have_attributes(next_plan_version: newer, next_plan_version_reason: "price_migration")
      notice = Notification.where(notification_type: "billing.price_change").sole
      expect(notice).to have_attributes(recipient_membership: admin, path: "/partner/invoices",
        title: "O preço do plano #{subscription.plan.name} muda em 01/11/2026")
      expect(notice.body).to include("R$ 1.800,00 por mês, até 500 colaboradores")
      expect(notice.deliveries.sole.channel).to eq("email")

      expect(described_class.migrate_price(subscription.reload)).to be_nil
      expect(kinds_and_totals(issue(Date.new(2026, 10, 29)).last).first).to eq([ "plan", 180_000 ])
    end

    it "waits for the next cycle when the 30 days end after this month's cycle day" do
      travel_to(Time.zone.local(2026, 10, 5, 9))

      expect(described_class.migrate_price(subscription.reload).effective_on).to eq(Date.new(2026, 12, 1))
    end
  end
end
