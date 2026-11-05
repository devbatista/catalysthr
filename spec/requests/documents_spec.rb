require "rails_helper"

# Spec 08, block 08a (RN-08-002 to RN-08-024, RN-08-081, D-604, D-642): the person's folder,
# the HR's upload, the password before a sensitive file, the review, the queue in the menu,
# the company's types and the process's document item.
RSpec.describe "Documents", type: :request do
  include ActiveJob::TestHelper

  let(:company) { create(:company, name: "Metalúrgica Serra Azul") }
  let(:brand) { create(:brand, owner: company, commercial_name: "Serra Azul RH") }
  let!(:hr_admin) { enable_mfa(create(:user, name: "Juliana Ribeiro", cpf: "98765432100")) }
  let(:position) { create_position(company) }
  let(:profile) { register_employee(company, by: hr_admin, position: position, name: "Rafael Moura Campos") }

  before do
    travel_to Time.zone.local(2026, 11, 3, 10)
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

  def pdf_upload(name = "rg.pdf")
    Rack::Test::UploadedFile.new(StringIO.new("%PDF-1.4\n%fake\n"), "application/pdf", original_filename: name)
  end

  def scan_clean(version)
    in_company do
      version.files.blobs.each { |blob| blob.file_scan.record!(Antivirus::Clamd::Result.new(signature: nil)) }
      perform_enqueued_jobs(only: Documents::ConsolidatePdfJob)
      version.reload
    end
  end

  def confirm_password
    post "/confirm-password", params: { password: "Catalyst#2026", return_to: "/" }
  end

  it "takes the documents out of \"Em breve\" and opens the review queue in the menu (D-598)" do
    get "/documents"

    expect(response.body).to include('href="/documents"', "Aguardando revisão · 0", "Nenhum documento aguardando revisão")
    expect(response.body).not_to include('href="/soon/documents"')
  end

  it "sends a document, asks the password before the sensitive file and reviews it (RN-08-013, RN-08-081, RN-08-023)" do
    get "/employees/#{profile.id}/documents"
    expect(response.body).to include("Documentos de Rafael Moura Campos", "Pessoais · 0", "Enviar documento")

    post "/employees/#{profile.id}/documents", params: { upload: { document_type_id: type("rg").id, files: [ pdf_upload ] } }
    document = in_company { Document.sole }
    expect(response).to redirect_to("/documents/#{document.id}")

    get "/documents/#{document.id}"
    expect(response).to redirect_to(%r{/confirm-password})
    confirm_password

    get "/documents/#{document.id}"
    expect(response.body).to include("RG", "Em varredura", "O arquivo está na varredura de vírus")
    version = in_company { document.versions.sole }
    get "/documents/#{document.id}/versions/#{version.id}/file"
    expect(response).to have_http_status(:not_found)

    scan_clean(version)
    get "/documents"
    expect(response.body).to include("Aguardando revisão · 1", "Rafael Moura Campos")

    expect do
      get "/documents/#{document.id}/versions/#{version.id}/file"
    end.to change { AccessEvent.where(kind: "sensitive_read", action: "document_opened").count }.by(1)
    expect(response.media_type).to eq("application/pdf")
    expect(response.headers["Cache-Control"]).to include("no-store")
    expect(response.headers["X-Frame-Options"]).to eq("SAMEORIGIN")
    expect(response.headers["Content-Security-Policy"]).to include("frame-ancestors 'self'")

    get "/documents/#{document.id}"
    expect(response.body).to include("<iframe", "A plataforma não comprova a autenticidade do documento")

    patch "/documents/#{document.id}/versions/#{version.id}/approve"
    expect(flash[:notice]).to eq("Versão aprovada.")
    expect(in_company { document.reload.current_version }).to eq(version)

    get "/documents"
    expect(response.body).to include("Aguardando revisão · 0")
  end

  it "asks a correction with the reason (RN-08-022) and takes a new version (RN-08-023)" do
    post "/employees/#{profile.id}/documents", params: { upload: { document_type_id: type("school_statement").id, files: [ pdf_upload ] } }
    document = in_company { Document.sole }
    version = scan_clean(in_company { document.versions.sole })

    patch "/documents/#{document.id}/versions/#{version.id}/correction", params: { correction_reason: "other" }
    expect(flash[:alert]).to include("Observação não pode ficar em branco")

    patch "/documents/#{document.id}/versions/#{version.id}/correction", params: { correction_reason: "illegible" }
    get "/documents/#{document.id}"
    expect(response.body).to include("Correção pedida", "Imagem ilegível")

    post "/documents/#{document.id}/versions", params: { upload: { files: [ pdf_upload ] } }
    expect(in_company { document.versions.count }).to eq(2)
  end

  it "refuses a .docx and lists the formats (CA-08-001)" do
    docx = Rack::Test::UploadedFile.new(StringIO.new("PK\x03\x04word"), "application/msword", original_filename: "rg.docx")
    post "/employees/#{profile.id}/documents", params: { upload: { document_type_id: type("rg").id, files: [ docx ] } }

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("Arquivos precisam ser PDF, JPG, PNG")
  end

  it "sends a dependent's certificate from the record (RN-04-043, D-604)" do
    dependent = in_company do
      profile.dependents.create!(name: "Pedro Campos", birth_date: Date.new(2020, 5, 1), relationship_type: "child", cpf: "11144477735")
    end
    get "/employees/#{profile.id}"
    expect(response.body).to include("Enviar certidão", "dependent_id=#{dependent.id}")

    post "/employees/#{profile.id}/documents", params: { upload: { document_type_id: type("dependent_birth_certificate").id,
      dependent_id: dependent.id, files: [ pdf_upload ] } }
    expect(in_company { Document.sole.dependent }).to eq(dependent)
  end

  it "keeps another company's folder out of reach (spec 01)" do
    other = create(:company)
    create(:membership, user: hr_admin, organization: other, roles: %w[hr_admin])
    outsider = register_employee(other, by: hr_admin, position: create_position(other), name: "Rita Souza")
    foreign = ActsAsTenant.with_tenant(other) { Document.create!(worker_profile: outsider, document_type: DocumentType.find_by!(code: "rg")) }

    get "/employees/#{outsider.id}/documents"
    expect(response).to have_http_status(:not_found)
    get "/documents/#{foreign.id}"
    expect(response).to have_http_status(:not_found)
  end

  describe "Empresa → Tipos de documento (RN-08-002, RN-08-004)" do
    it "creates the company's own type and turns off a platform's one" do
      get "/document-types"
      expect(response.body).to include("Da plataforma · 20", "Comprovante de residência", "A empresa ainda não criou tipos próprios")

      post "/document-types", params: { document_type: { name: "Certificado NR-35", category: "other", expiration_rule: "none",
        alert_days: "30", max_files: "1" } }
      expect(response).to redirect_to("/document-types")
      expect(in_company { DocumentType.find_by!(name: "Certificado NR-35").company_id }).to eq(company.id)

      patch "/document-types/#{type("photo").id}/setting", params: { setting: { enabled: "0" } }
      expect(in_company { DocumentType.usable.where(id: type("photo").id) }).to be_empty

      patch "/document-types/#{type("photo").id}", params: { document_type: { name: "Foto" } }
      expect(response).to have_http_status(:forbidden)
    end

    it "sets the periodic ASO's months for a risky position (D-272)" do
      welder = create_position(company, name: "Soldador", cbo_code: "724315")
      aso = type("aso_periodic")

      post "/document-types/#{aso.id}/position-expirations", params: { position_expiration: { position_id: welder.id, expiration_months: "6" } }
      get "/document-types"
      expect(response.body).to include("Soldador: a cada 6 meses")
    end
  end

  it "adds a document item, of one type, to the company's model (RN-06-010, D-642)" do
    template = in_company { ProcessTemplate.create!(kind: "admission", name: "Admissão CLT") }
    own = in_company { DocumentType.create!(name: "Certificado NR-35", category: "other") }

    get "/process-templates/#{template.id}/items/new", params: { kind: "document" }
    expect(response.body).to include("Tipo de documento", "Certificado NR-35 (Outros)", "RG (Pessoais)")

    post "/process-templates/#{template.id}/items", params: { item: { kind: "document", title: "Certificado", responsible_role: "employee",
      required: "1", config: { document_type_id: own.id } } }
    expect(in_company { template.items.sole.config }).to eq("document_type_id" => own.id)
    get "/process-templates/#{template.id}"
    expect(response.body).to include("Certificado NR-35")
  end

  it "sends the document of a process's item from its page (RN-06-010, D-642)" do
    instance = in_company do
      template = ProcessTemplate.create!(kind: "admission", name: "Admissão CLT")
      template.items.create!(position: 1, kind: "document", title: "RG", responsible_role: "employee", config: { "document_type_id" => type("rg").id })
      template.update!(status: "active")
      Processes::Start.call(template: template.reload, employment: profile.employments.sole, started_by: hr_admin,
        starter: Membership.find_by!(user: hr_admin, organization: company), anchors: { "work_start" => Date.current + 7 })
    end
    item = in_company { instance.items.sole }

    get "/processes/#{instance.id}"
    expect(response.body).to include("Enviar documento", "process_item_id=#{item.id}")

    get "/employees/#{profile.id}/documents/new", params: { document_type_id: type("rg").id, process_item_id: item.id }
    expect(response.body).to include("Para: RG")

    post "/employees/#{profile.id}/documents", params: { upload: { document_type_id: type("rg").id, process_item_id: item.id,
      files: [ pdf_upload ] } }
    expect(in_company { item.reload }).to be_submitted
    get "/processes/#{instance.id}"
    expect(response.body).to include("Ver o documento", "Documento de &quot;RG&quot; enviado")
  end
end
