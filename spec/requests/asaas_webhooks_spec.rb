require "rails_helper"

# Spec 19, RN-19-106 and P-19-33 (D-633): Asaas's notices about the NFS-e, accepted only with
# the webhook's token, on any host and without sign-in. The notice is not trusted: the job
# reads the note in the API.
RSpec.describe "Asaas webhooks", type: :request do
  include ActiveJob::TestHelper

  let(:token) { "token-do-webhook-com-mais-de-32-caracteres" }
  let(:notice) { { id: "evt_1", event: "INVOICE_AUTHORIZED", invoice: { id: "inv_000000000001", status: "AUTHORIZED" } } }

  before do
    Rails.configuration.x.asaas_webhook_token = token
    host! "admin.catalysthr.com.br"
  end

  def deliver(body = notice, header: token)
    post "/webhooks/asaas", params: body.to_json,
      headers: { "Content-Type" => "application/json", "asaas-access-token" => header }.compact
  end

  it "answers 200 and reads the note in the API" do
    expect { deliver }.to have_enqueued_job(Billing::SyncServiceInvoiceJob).with("inv_000000000001")
    expect(response).to have_http_status(:ok)
  end

  it "refuses a notice without the token or with another one" do
    expect { deliver(header: nil) }.not_to have_enqueued_job
    expect(response).to have_http_status(:unauthorized)
    deliver(header: "outro")
    expect(response).to have_http_status(:unauthorized)
  end

  it "refuses every notice while no token is set" do
    Rails.configuration.x.asaas_webhook_token = nil

    deliver

    expect(response).to have_http_status(:unauthorized)
  end

  it "answers 200 to a notice that is not about a note, without reading anything" do
    expect { deliver({ id: "evt_2", event: "PAYMENT_RECEIVED", payment: { id: "pay_1" } }) }.not_to have_enqueued_job
    expect { deliver(notice.merge(invoice: { id: "../fiscalInfo" })) }.not_to have_enqueued_job
    expect(response).to have_http_status(:ok)
  end

  it "applies the note the API returns, end to end" do
    Flipper.enable(FeatureFlags::NFSE)
    configure_asaas
    stub_asaas_invoice(asaas_invoice(id: "inv_000000000404")).to_return(status: 404, body: { errors: [] }.to_json)

    perform_enqueued_jobs { deliver(notice.merge(invoice: { id: "inv_000000000404" })) }

    expect(response).to have_http_status(:ok)
  end
end
