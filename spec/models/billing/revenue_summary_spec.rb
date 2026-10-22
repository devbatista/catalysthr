require "rails_helper"

# Spec 19, block 19g (RN-19-090, D-610, D-626): the Revenue block of the team's panel.
RSpec.describe Billing::RevenueSummary do
  around { |example| travel_to(Time.zone.local(2026, 10, 22, 10)) { example.run } }

  let(:today) { Date.new(2026, 10, 22) }
  let(:summary) { described_class.new(today) }

  def invoice_for(account, status: "open", issued_at: Time.current, due_on: today, checkout: false, paid_at: nil, lines: [ [ "plan", 10_000 ] ])
    number = (Invoice.maximum(:number) || 0) + 1
    invoice = account.invoices.new(number: number, period_start: due_on - number, period_end: due_on - number + 29, due_on: due_on,
      status: status, total_cents: lines.sum(&:last), issued_at: issued_at, checkout: checkout, paid_at: paid_at)
    lines.each.with_index(1) do |(kind, cents), position|
      invoice.lines.new(position: position, kind: kind, description: kind, quantity: 1, unit_cents: cents, total_cents: cents)
    end
    invoice.tap(&:save!)
  end

  describe "#recurring" do
    it "sums the plan, the modules and the add-ons of the next cycle of the charged contracts, without trials (D-626)" do
      partner = contract_for(create(:partner))
      price = create(:add_on_price)
      partner.items.create!(kind: "add_on", add_on_price: price, starts_on: today)

      direct_company = create(:company)
      direct = contract_for(direct_company, modules: [])
      DailyUsage.create!(billing_account: direct.billing_account, company: direct_company, date: today - 2, active_employees: 10)
      DailyUsage.create!(billing_account: direct.billing_account, company: direct_company, date: today - 1, active_employees: 50)

      pre_activation = contract_for(create(:partner))
      pre_activation.update!(activated_on: nil, pre_activation_price: create(:pre_activation_price))

      contract_for(create(:partner), status: "trialing")

      # Partner: R$ 1.500 + ponto R$ 400 + folha R$ 600; direct: 50 × R$ 12 (last recorded
      # day); pre-activation: R$ 19,90.
      expect(summary.recurring).to have_attributes(monthly_cents: 250_000 + 60_000 + 1_990, add_on_cents: 9_900, contracts: 3,
        total_cents: 321_890)
    end

    it "applies the direct company's minimum when no day is recorded" do
      contract_for(create(:company), modules: [])

      expect(summary.recurring.monthly_cents).to eq(30_000)
    end
  end

  it "sums the overage lines of the invoices issued this month, without the voided ones" do
    account = contract_for(create(:partner)).billing_account
    invoice_for(account, lines: [ [ "plan", 150_000 ], [ "overage_ai", 2_500 ], [ "overage_employees", 3_000 ] ])
    invoice_for(account, status: "void", lines: [ [ "overage_whatsapp", 700 ] ])
    invoice_for(account, issued_at: Time.zone.local(2026, 9, 30, 23), lines: [ [ "overage_ai", 9_999 ] ])

    expect(summary.overage_invoiced_cents).to eq(5_500)
  end

  it "shows the overdue amount and the contracts with an overdue invoice by status" do
    late = contract_for(create(:partner))
    late.update!(status: "read_only")
    invoice_for(late.billing_account, status: "overdue", due_on: today - 16, lines: [ [ "plan", 150_000 ] ])
    cancelled = contract_for(create(:partner))
    cancelled.update!(status: "closing", closing_on: today)
    contract_for(create(:partner), status: "past_due")

    expect(summary.overdue_cents).to eq(150_000)
    expect(summary.late_contracts).to eq("past_due" => 0, "read_only" => 1, "closing" => 0)
  end

  it "lists the scheduled cancellations and counts the trials running" do
    scheduled = contract_for(create(:partner, name: "Aurora"))
    scheduled.update!(status: "cancel_scheduled", cancel_on: today + 10)
    contract_for(create(:partner), status: "trialing")
    contract_for(create(:company), status: "trialing")

    expect(summary.scheduled_cancellations).to eq([ scheduled ])
    expect(summary.trials_running).to eq(2)
  end

  it "converts the trials ended in the last 90 days that contracted, in the trial or after it (D-626)" do
    expired = contract_for(create(:partner), status: "trial_expired")
    expired.update!(trial_ends_on: today - 10)

    early = contract_for(create(:partner), status: "trialing")
    early.update!(status: "active", trial_ends_on: today + 5, activated_on: today - 5)
    invoice_for(early.billing_account, status: "paid", checkout: true, paid_at: Time.current - 5.days)

    after = contract_for(create(:company), status: "trialing")
    after.update!(status: "active", trial_ends_on: today - 20)
    invoice_for(after.billing_account, status: "paid", checkout: true, paid_at: Time.current - 15.days)

    old = contract_for(create(:partner), status: "trial_expired")
    old.update!(trial_ends_on: today - 100)
    contract_for(create(:partner), status: "trialing")

    expect(summary.conversion).to have_attributes(ended: 3, converted: 2, percent: 66)
  end

  it "has no conversion without trials ended" do
    expect(summary.conversion).to have_attributes(ended: 0, percent: nil)
  end
end
