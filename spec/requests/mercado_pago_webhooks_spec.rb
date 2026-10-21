require "rails_helper"

# Spec 19, RN-19-046 (CA-19-007, D-622): Mercado Pago's notice, at the admin host, without
# sign-in or CSRF token, accepted only with the account's signature; the order is read in
# the API.
RSpec.describe "Mercado Pago webhooks", type: :request do
  include ActiveJob::TestHelper

  let(:company) { create(:company) }
  let(:subscription) { contract_for(company) }
  let(:invoice) { Billing::Invoicing.issue_due(subscription, Date.current, lead: 0).sole }
  let(:payment) do
    stub_create_order
    Billing::Pix.ensure_for(invoice)
  end

  around { |example| travel_to(Time.zone.local(2026, 10, 15, 10)) { example.run } }

  before do
    Flipper.enable(FeatureFlags::BILLING)
    configure_mercado_pago
    host! "admin.catalysthr.com.br"
    subscription.billing_account.update!(billing_email: "financeiro@serraazul.example")
  end

  def notify(data_id, signature: mp_signature(data_id, "req-1"), type: "order")
    post "/webhooks/mercado-pago?data.id=#{data_id}&type=#{type}", params: { action: "order.processed", data: { id: data_id } }.to_json,
      headers: { "Content-Type" => "application/json", "x-signature" => signature, "x-request-id" => "req-1" }
  end

  it "pays the invoice on the notice of the paid order, bringing the contract back (CA-19-007)" do
    subscription.update!(status: "read_only")
    stub_get_order(mp_order(id: payment.provider_order_id, external_reference: payment.id, amount_cents: 30_000, status: "processed",
      status_detail: "accredited", paid_cents: 30_000))

    perform_enqueued_jobs(only: Billing::SyncOrderJob) { notify(payment.provider_order_id) }

    expect(response).to have_http_status(:ok)
    expect(invoice.reload).to be_paid
    expect(subscription.reload).to be_active
  end

  it "refuses a notice without the account's signature, reading nothing" do
    notify(payment.provider_order_id, signature: mp_signature(payment.provider_order_id, "req-1", secret: "outro"))

    expect(response).to have_http_status(:unauthorized)
    expect(Billing::SyncOrderJob).not_to have_been_enqueued
  end

  it "answers the notices of other topics without reading them" do
    notify("123456", type: "payment")

    expect(response).to have_http_status(:ok)
    expect(Billing::SyncOrderJob).not_to have_been_enqueued
  end
end
