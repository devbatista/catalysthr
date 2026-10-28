require "rails_helper"

# Spec 19, RN-19-106, RN-19-108 and RN-19-111 (CA-19-013, D-633): the NFS-e on the invoice.
# The team sees Asaas's refusal, the history and "Emitir de novo"; the client sees only that
# the note is being processed.
RSpec.describe "Service invoices", type: :request do
  include ActiveJob::TestHelper

  let(:partner) { create(:partner, name: "Aurora Gestão de Pessoas") }
  let(:brand) { create(:brand, owner: partner, commercial_name: "Aurora RH") }
  let(:invoice) { Billing::Invoicing.issue_due(contract_for(partner), Date.current, lead: 0).sole }
  let(:note) do
    perform_enqueued_jobs(only: []) do
      invoice.update!(status: "paid", paid_at: Time.current)
      invoice.service_invoice
    end
  end

  around { |example| travel_to(Time.zone.local(2026, 10, 29, 10)) { example.run } }

  before do
    Flipper.enable(FeatureFlags::SIGN_IN)
    Flipper.enable(FeatureFlags::BILLING)
    Flipper.enable(FeatureFlags::NFSE)
    publish_platform_legal_documents
    note.update!(status: "error", error_message: "Código NBS inválido.", errors_count: 1)
  end

  def sign_in_team(role)
    host! "admin.catalysthr.com.br"
    user = enable_mfa(create(:user, platform_role: role, cpf: "52998224725", name: "Fernanda Financeiro"))
    sign_in_with_mfa("52998224725", user)
  end

  it "shows the team the refusal and the history, and sends the note again (CA-19-013)" do
    sign_in_team("finance")

    get "/invoices/#{invoice.id}"
    expect(response.body).to include("Nota fiscal (NFS-e)", "Com erro", "Código NBS inválido.", "Emitir de novo", "Histórico da nota",
      "Aguardando envio")

    expect { post "/invoices/#{invoice.id}/service-invoice/reissue" }.to have_enqueued_job(Billing::IssueServiceInvoiceJob)

    expect(response).to redirect_to("/invoices/#{invoice.id}")
    expect(flash[:notice]).to eq("Nota enviada de novo ao Asaas.")
    expect(note.reload).to be_pending
    post "/invoices/#{invoice.id}/service-invoice/reissue"
    expect(flash[:alert]).to eq("Só uma nota com erro pode ser emitida de novo.")
  end

  it "lets the support read the note, but not send it again" do
    sign_in_team("support")

    get "/invoices/#{invoice.id}"
    expect(response.body).to include("Código NBS inválido.")
    expect(response.body).not_to include("Emitir de novo")

    post "/invoices/#{invoice.id}/service-invoice/reissue"
    expect(response).to have_http_status(:forbidden)
  end

  it "shows the partner only that the note is being processed" do
    brand.subdomains.create!(slug: "aurora")
    host! "aurora.painel.catalysthr.com.br"
    user = enable_mfa(create(:user, cpf: "98765432100"))
    create(:membership, user: user, organization: partner, roles: %w[partner_admin])
    accept_legal_documents(user, brand)
    sign_in_with_mfa("98765432100", user)

    get "/partner/invoices/#{invoice.id}"

    expect(response.body).to include("Nota fiscal (NFS-e)", "Em processamento")
    expect(response.body).not_to include("Código NBS inválido.", "Emitir de novo", "Histórico da nota")
  end

  it "hides the note while the notes are off (D-633)" do
    Flipper.disable(FeatureFlags::NFSE)
    sign_in_team("finance")

    get "/invoices/#{invoice.id}"
    expect(response.body).not_to include("Nota fiscal (NFS-e)")
    post "/invoices/#{invoice.id}/service-invoice/reissue"
    expect(response).to have_http_status(:not_found)
  end
end
