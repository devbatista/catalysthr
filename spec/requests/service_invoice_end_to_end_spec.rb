require "rails_helper"

# Spec 19, CA-19-012 (RN-19-104 to RN-19-107, D-633), end to end: the PIX paid, Mercado Pago's
# webhook confirms it, the note is scheduled in Asaas, and Asaas's webhook of the city's
# authorization puts the PDF and the XML on the invoice and tells the responsible.
RSpec.describe "Service invoice end to end", type: :request do
  include ActiveJob::TestHelper

  let(:partner) { create(:partner, legal_name: "Aurora Gestão de Pessoas Ltda") }
  let(:subscription) { contract_for(partner) }
  let(:account) { subscription.billing_account }
  let(:admin) { create(:user, cpf: "39053344705") }
  let(:invoice) { Billing::Invoicing.issue_due(subscription, Date.current, lead: 0).sole }

  around { |example| travel_to(Time.zone.local(2026, 10, 29, 10)) { example.run } }

  before do
    Flipper.enable(FeatureFlags::BILLING)
    Flipper.enable(FeatureFlags::NFSE)
    configure_mercado_pago
    configure_asaas
    Rails.configuration.x.asaas_webhook_token = "token-do-webhook-com-mais-de-32-caracteres"
    create(:membership, user: admin, organization: partner, roles: %w[partner_admin])
    account.update!(responsible_user: admin)
    FiscalSetting.current.tap { |setting| setting.assign_attributes(service_code: "010501", updated_by: create(:user, platform_role: "finance")) }.save!
    host! "admin.catalysthr.com.br"
  end

  it "takes a PIX paid to an authorized note with its files on the invoice (CA-19-012)" do
    stub_create_order
    payment = perform_enqueued_jobs(only: []) { Billing::Pix.ensure_for(invoice) }
    stub_get_order(mp_order(id: payment.provider_order_id, external_reference: payment.id, amount_cents: invoice.total_cents,
      status: "processed", status_detail: "accredited", paid_cents: invoice.total_cents))
    stub_asaas(:get, "/customers?externalReference=#{account.id}", body: { data: [] })
    stub_asaas(:post, "/customers", body: { id: "cus_000001" })
    stub_request(:get, %r{#{Regexp.escape(AsaasStub::BASE_URL)}/invoices\?externalReference=}).to_return(status: 200, body: { data: [] }.to_json)
    stub_asaas(:post, "/invoices", body: { id: "inv_000000000001", status: "SCHEDULED", effectiveDate: "2026-10-29" })

    perform_enqueued_jobs do
      post "/webhooks/mercado-pago?data.id=#{payment.provider_order_id}&type=order",
        headers: { "x-signature" => mp_signature(payment.provider_order_id, "req-1"), "x-request-id" => "req-1" }
    end

    note = invoice.reload.service_invoice
    expect(invoice).to be_paid
    expect(note).to have_attributes(status: "scheduled", asaas_invoice_id: "inv_000000000001")

    stub_asaas_invoice(asaas_invoice(id: "inv_000000000001"))
    stub_asaas_files
    perform_enqueued_jobs do
      post "/webhooks/asaas", params: { id: "evt_1", event: "INVOICE_AUTHORIZED", invoice: { id: "inv_000000000001" } }.to_json,
        headers: { "Content-Type" => "application/json", "asaas-access-token" => "token-do-webhook-com-mais-de-32-caracteres" }
    end

    expect(note.reload).to have_attributes(status: "authorized", number: "202600000000001")
    expect(note.pdf.download).to eq("%PDF-1.7 nota")
    expect(note.xml.download).to eq("<NFSe/>")
    expect(Notification.where(notification_type: "billing.nfse_issued").sole.recipient_user).to eq(admin)
  end
end
