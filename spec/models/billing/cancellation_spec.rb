require "rails_helper"

# Spec 19, RN-19-062 and RN-19-063 (D-489, D-625): the cancellation asked by the client
# takes effect at the end of the paid cycle, can be undone until then, and then the contract
# goes into closing; a partner's companies are told 30 days before the end.
RSpec.describe Billing::Cancellation do
  let(:partner) { create(:partner, name: "Aurora Gestão de Pessoas") }
  let(:subscription) { contract_for(partner) }
  let(:account) { subscription.billing_account }
  let(:admin) { create(:membership, organization: partner, roles: %w[partner_admin]) }
  let!(:client_hr) { create(:membership, organization: create(:company, partner: partner, name: "Metalúrgica Serra Azul"), roles: %w[hr_admin]) }
  let!(:first) { Billing::Invoicing.issue_due(subscription, Date.current, lead: 0).sole }

  around { |example| travel_to(Time.zone.local(2026, 10, 1, 9)) { example.run } }

  before do
    Flipper.enable(FeatureFlags::BILLING)
    account.update!(responsible_user: admin.user)
    first.update!(status: "paid", paid_at: Time.current)
  end

  def schedule(today: Date.current, reason: "price", text: nil)
    described_class.schedule(subscription, by: admin.user, reason: reason, text: text, today: today)
  end

  it "takes effect at the end of the paid cycle and tells the responsible (RN-19-062)" do
    travel_to(Time.zone.local(2026, 10, 10, 9))

    expect(schedule).to eq(:scheduled)

    expect(subscription.reload).to have_attributes(status: "cancel_scheduled", cancel_on: Date.new(2026, 10, 31), cancel_reason: "price",
      cancel_requested_by: admin.user)
    notice = Notification.find_by!(notification_type: "billing.cancel_scheduled")
    expect(notice).to have_attributes(recipient_user: admin.user, title: "Cancelamento de Aurora Gestão de Pessoas agendado para 31/10/2026")
  end

  it "voids the next cycle's invoice already issued and not paid" do
    travel_to(Time.zone.local(2026, 10, 29, 9))
    november = Billing::Invoicing.issue_due(subscription, Date.current).sole

    schedule

    expect(november.reload).to have_attributes(status: "void", void_reason: "contract_cancelled")
    expect(subscription.reload.cancel_on).to eq(Date.new(2026, 10, 31))
    expect(Billing::Invoicing.issue_due(subscription, Date.new(2026, 10, 30))).to be_empty
  end

  it "keeps a next cycle already paid, and takes effect at its end" do
    travel_to(Time.zone.local(2026, 10, 29, 9))
    Billing::Invoicing.issue_due(subscription, Date.current).sole.update!(status: "paid", paid_at: Time.current)

    schedule

    expect(subscription.reload.cancel_on).to eq(Date.new(2026, 11, 30))
  end

  it "asks the reason, and the text for another one" do
    expect(schedule(reason: "")).to eq(:reason)
    expect(schedule(reason: "other")).to eq(:reason_text)
    expect(schedule(reason: "other", text: "Mudança de diretoria")).to eq(:scheduled)
    expect(subscription.reload.cancel_reason_text).to eq("Mudança de diretoria")
  end

  it "is undone until the day, issuing again the cycle it voided" do
    travel_to(Time.zone.local(2026, 10, 29, 9))
    Billing::Invoicing.issue_due(subscription, Date.current)
    schedule

    expect(described_class.undo(subscription, by: admin.user)).to eq(:undone)

    expect(subscription.reload).to have_attributes(status: "active", cancel_on: nil, cancel_undone_by: admin.user)
    expect(Billing::Invoicing.issue_due(subscription, Date.current).sole).to have_attributes(period_start: Date.new(2026, 11, 1), status: "open")
  end

  it "puts the contract into closing the day after, and no longer undoes it" do
    schedule

    described_class.apply_due(Date.new(2026, 10, 31))
    expect(subscription.reload).to be_cancel_scheduled

    described_class.apply_due(Date.new(2026, 11, 1))
    expect(subscription.reload).to have_attributes(status: "closing", closing_on: Date.new(2026, 11, 1))
    expect(described_class.undo(subscription, by: admin.user, today: Date.new(2026, 11, 1))).to eq(:not_scheduled)
  end

  it "tells the portfolio once, 30 days before the end, or at the request when less is left (RN-19-063)" do
    travel_to(Time.zone.local(2026, 10, 29, 9))
    Billing::Invoicing.issue_due(subscription, Date.current).sole.update!(status: "paid", paid_at: Time.current)
    schedule
    expect(Notification.where(notification_type: "billing.partner_cancelled")).to be_empty

    described_class.apply_due(Date.new(2026, 10, 31))
    described_class.apply_due(Date.new(2026, 11, 1))
    2.times { described_class.apply_due(Date.new(2026, 11, 2)) }

    notice = Notification.where(notification_type: "billing.partner_cancelled").sole
    expect(notice).to have_attributes(recipient_user: client_hr.user, title: "O contrato de Aurora Gestão de Pessoas com a CatalystHR termina em 30/11/2026")
    expect(notice.body).not_to include("R$")
  end

  it "keeps the cancellation through a late invoice and its payment" do
    travel_to(Time.zone.local(2026, 10, 29, 9))
    november = Billing::Invoicing.issue_due(subscription, Date.current).sole
    november.update!(status: "paid", paid_at: Time.current)
    schedule
    first.update!(status: "open", paid_at: nil)

    Billing::Dunning.run(Date.new(2026, 10, 30))
    expect(subscription.reload).to have_attributes(status: "read_only", cancel_on: Date.new(2026, 11, 30))

    first.update!(status: "paid", paid_at: Time.current)
    Billing::Dunning.run(Date.new(2026, 10, 31))
    expect(subscription.reload).to have_attributes(status: "cancel_scheduled", cancel_on: Date.new(2026, 11, 30))
  end
end
