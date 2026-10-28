require "rails_helper"

# Spec 19, RN-19-107 (CA-19-012, D-564, D-633): the authorized NFS-e on the invoice, with its
# PDF and XML served by the application to who reads the invoice, and to no one else.
RSpec.describe "Service invoice files", type: :request do
  include ActiveJob::TestHelper

  let(:partner) { create(:partner, name: "Aurora Gestão de Pessoas") }
  let(:brand) { create(:brand, owner: partner, commercial_name: "Aurora RH") }
  let(:invoice) { Billing::Invoicing.issue_due(contract_for(partner), Date.current, lead: 0).sole }
  let(:other_invoice) { Billing::Invoicing.issue_due(contract_for(create(:partner, name: "Outro Parceiro")), Date.current, lead: 0).sole }

  around { |example| travel_to(Time.zone.local(2026, 10, 29, 10)) { example.run } }

  before do
    Flipper.enable(FeatureFlags::SIGN_IN)
    Flipper.enable(FeatureFlags::BILLING)
    Flipper.enable(FeatureFlags::NFSE)
    publish_platform_legal_documents
    note = perform_enqueued_jobs(only: []) do
      invoice.update!(status: "paid", paid_at: Time.current)
      invoice.service_invoice
    end
    note.update!(status: "authorized", number: "202600000000001", verification_code: "ABCD-1234", authorized_at: Time.current)
    note.pdf.attach(io: StringIO.new("%PDF-1.7 nota"), filename: "nfse-202600000000001.pdf", content_type: "application/pdf")
    note.xml.attach(io: StringIO.new("<NFSe/>"), filename: "nfse-202600000000001.xml", content_type: "application/xml")
  end

  def sign_in_partner_admin
    brand.subdomains.create!(slug: "aurora")
    host! "aurora.painel.catalysthr.com.br"
    user = enable_mfa(create(:user, cpf: "98765432100"))
    create(:membership, user: user, organization: partner, roles: %w[partner_admin])
    accept_legal_documents(user, brand)
    sign_in_with_mfa("98765432100", user)
  end

  it "shows the partner the issued note and hands over its PDF and XML (CA-19-012)" do
    sign_in_partner_admin

    get "/partner/invoices/#{invoice.id}"
    expect(response.body).to include("Emitida", "202600000000001", "ABCD-1234", "Baixar PDF", "Baixar XML")

    get "/partner/invoices/#{invoice.id}/service-invoice/pdf"
    expect(response).to have_http_status(:ok)
    expect(response.body).to eq("%PDF-1.7 nota")
    expect(response.headers["Content-Disposition"]).to include("attachment", "nfse-202600000000001.pdf")
    expect(response.headers["Cache-Control"]).to include("no-store")

    get "/partner/invoices/#{invoice.id}/service-invoice/xml"
    expect(response.body).to eq("<NFSe/>")
  end

  it "keeps another partner's note out of reach" do
    sign_in_partner_admin

    get "/partner/invoices/#{other_invoice.id}/service-invoice/pdf"

    expect(response).to have_http_status(:not_found)
  end

  it "shows the partner a note being cancelled with the reason, and a refused cancellation as the valid note (RN-19-110)" do
    note = invoice.service_invoice
    note.update!(status: "cancelling", cancel_reason: "Estorno da fatura #{invoice.display_number}")
    sign_in_partner_admin

    get "/partner/invoices/#{invoice.id}"
    expect(response.body).to include("Em cancelamento", "Motivo do cancelamento: Estorno da fatura #{invoice.display_number}.")

    note.update!(status: "cancel_denied", error_message: "Prazo de cancelamento expirado.")
    get "/partner/invoices/#{invoice.id}"
    expect(response.body).to include("Emitida", "Baixar PDF")
    expect(response.body).not_to include("Prazo de cancelamento expirado.", "Estorno da fatura")
  end

  it "shows the team the refused cancellation, to settle with the accountant (P-19-35)" do
    invoice.service_invoice.update!(status: "cancel_denied", error_message: "Prazo de cancelamento expirado.",
      cancel_reason: "Estorno da fatura #{invoice.display_number}")
    host! "admin.catalysthr.com.br"
    user = enable_mfa(create(:user, platform_role: "finance", cpf: "52998224725"))
    sign_in_with_mfa("52998224725", user)

    get "/invoices/#{invoice.id}"

    expect(response.body).to include("Cancelamento recusado", "O cancelamento da nota foi recusado", "Prazo de cancelamento expirado.",
      "Trate o cancelamento com o contador", "Motivo do cancelamento")
    expect(response.body).not_to include("Emitir de novo")
  end

  it "hands the team the files too, and nothing for an invoice without a note" do
    host! "admin.catalysthr.com.br"
    user = enable_mfa(create(:user, platform_role: "support", cpf: "52998224725"))
    sign_in_with_mfa("52998224725", user)

    get "/invoices/#{invoice.id}/service-invoice/xml"
    expect(response.body).to eq("<NFSe/>")

    get "/invoices/#{other_invoice.id}/service-invoice/pdf"
    expect(response).to have_http_status(:not_found)
  end
end
