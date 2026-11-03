require "rails_helper"

# Spec 08, block 08b (RN-08-031 to RN-08-054, D-643): the screens of the expirations, the
# requests and the publications asking for an acknowledgment, with the refusal and the
# receipt behind the password.
RSpec.describe "Document follow-ups", type: :request do
  include ActiveJob::TestHelper

  let(:company) { create(:company, name: "Metalúrgica Serra Azul") }
  let(:brand) { create(:brand, owner: company, commercial_name: "Serra Azul RH") }
  let!(:hr_admin) { enable_mfa(create(:user, name: "Juliana Ribeiro", cpf: "98765432100")) }
  let(:position) { create_position(company) }
  let(:profile) { register_employee(company, by: hr_admin, position: position, name: "Marcos Teles") }
  let(:other) { register_employee(company, by: hr_admin, position: position, name: "Lívia Prado") }

  before do
    travel_to Time.zone.local(2026, 10, 3, 10)
    create(:membership, user: hr_admin, organization: company, roles: %w[hr_admin])
    brand.subdomains.create!(slug: "serraazul")
    Flipper.enable(FeatureFlags::SIGN_IN)
    publish_platform_legal_documents
    load_platform_document_types
    host! "serraazul.painel.catalysthr.com.br"
    accept_legal_documents(hr_admin, brand)
    sign_in_with_mfa("98765432100", hr_admin)
  end

  after { travel_back }

  def in_company(&) = ActsAsTenant.with_tenant(company, &)

  def type(code) = PlatformDocumentType.find_by!(code: code)

  def pdf_upload(content = "%PDF-1.4\n%fake\n")
    Rack::Test::UploadedFile.new(StringIO.new(content), "application/pdf", original_filename: "doc.pdf")
  end

  def scan_clean(blobs)
    in_company do
      Array(blobs).each { |blob| blob.file_scan.record!(Antivirus::Clamd::Result.new(signature: nil)) }
      perform_enqueued_jobs(only: Documents::ConsolidatePdfJob)
    end
  end

  it "lists the expiring CNH in Vencimentos (RN-08-031)" do
    document = in_company do
      form = Documents::Upload.new(worker_profile: profile, document_type: DocumentType.find_by!(code: "cnh"), files: [ pdf_upload ], by: hr_admin)
      form.save
      scan_clean(form.version.files.blobs)
      Documents::Review.new(form.version.reload, by: hr_admin).approve(valid_until: Date.new(2026, 11, 2))
      form.document.reload
    end

    get "/documents/expirations"
    expect(response.body).to include("Vencimentos", "1 documento", "CNH", "Marcos Teles", "02/11/2026", "Vencendo")
    get "/documents/#{document.id}"
    expect(response).to redirect_to(%r{/confirm-password})
  end

  it "asks a document from a group and shows its panel (RN-08-040, RN-08-041)" do
    profile
    other
    get "/document-requests/new"
    expect(response.body).to include("Pedir documento", "Com dependente para salário-família", "Marcos Teles")

    post "/document-requests", params: { request: { document_type_id: type("school_statement").id, due_on: "2026-10-20", message: "Até o dia 20" },
      audience: { unit_ids: [ company.headquarters.id ] } }
    request = in_company { DocumentRequest.sole }
    expect(response).to redirect_to("/document-requests/#{request.id}")
    expect(flash[:notice]).to eq("Documento pedido a 2 pessoas.")

    get "/document-requests/#{request.id}"
    expect(response.body).to include("Pedido de Declaração escolar", "Até o dia 20", "Lívia Prado", "Marcos Teles", "Pendente")
    get "/document-requests"
    expect(response.body).to include("Declaração escolar", "0 de 2")
  end

  it "refuses a request without anyone" do
    post "/document-requests", params: { request: { document_type_id: type("school_statement").id }, audience: { family_allowance: "1" } }

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("Nenhuma pessoa do seu escopo, com vínculo aberto, atende a esses filtros")
  end

  it "publishes with acknowledgment, records the refusal after the date and gives the receipt behind the password (RN-08-050 to RN-08-054)" do
    get "/document-publications/new", params: { audience: { worker_profile_ids: [ profile.id ] } }
    expect(response.body).to include("Publicar com ciência", "não significa concordância nem assinatura")

    post "/document-publications", params: { publication: { title: "Advertência", document_type_id: type("school_statement").id,
      due_on: "2026-10-05", file: pdf_upload("%PDF-1.4 advertencia") }, audience: { worker_profile_ids: [ profile.id ] } }
    publication = in_company { DocumentPublication.sole }
    expect(response).to redirect_to("/document-publications/#{publication.id}")
    acknowledgment = in_company { publication.acknowledgments.sole }
    scan_clean(in_company { acknowledgment.version.files.blobs })

    get "/document-publications/#{publication.id}"
    expect(response.body).to include("Advertência", "Aguardando ciência", "Marcos Teles")
    expect(response.body).not_to include("Registrar ciência recusada")

    # Past the date, without moving the clock, which would end the session.
    in_company { acknowledgment.update_columns(due_on: Date.new(2026, 10, 2)) }
    get "/document-publications/#{publication.id}"
    expect(response.body).to include("Registrar ciência recusada", "Atrasado")

    patch "/document-publications/#{publication.id}/acknowledgments/#{acknowledgment.id}/refuse",
      params: { refused_note: "Recusou assinar", witnesses: { "0" => { name: "José Alves", cpf: "529.982.247-25" }, "1" => { name: "", cpf: "" } } }
    expect(flash[:notice]).to eq("Ciência recusada registrada para Marcos Teles.")
    expect(in_company { acknowledgment.reload }).to be_refused

    get "/document-publications/#{publication.id}/receipt"
    expect(response).to redirect_to(%r{/confirm-password})
    post "/confirm-password", params: { password: "Catalyst#2026", return_to: "/" }
    expect do
      get "/document-publications/#{publication.id}/receipt"
    end.to change { AccessEvent.where(action: "acknowledgment_receipt").count }.by(1)
    expect(response.media_type).to eq("application/pdf")

    get "/employees/#{profile.id}/documents?category=statements"
    expect(response.body).to include("Declaração escolar", "Publicar com ciência", "Pedir documento")
  end

  it "keeps another company's publication out of reach (spec 01)" do
    other_company = create(:company)
    create(:membership, user: hr_admin, organization: other_company, roles: %w[hr_admin])
    outsider = register_employee(other_company, by: hr_admin, position: create_position(other_company), name: "Rita Souza")
    publication = ActsAsTenant.with_tenant(other_company) do
      ability = Ability.new(hr_admin, area: :panel, company: other_company)
      form = Documents::Publish.new(title: "Aviso", document_type: DocumentType.find_by!(code: "school_statement"), file: pdf_upload,
        audience_filter: { "worker_profile_ids" => [ outsider.id ] }, due_on: Date.new(2026, 10, 5), by: hr_admin, ability: ability)
      form.save
      form.publication
    end

    get "/document-publications/#{publication.id}"
    expect(response).to have_http_status(:not_found)
  end
end
