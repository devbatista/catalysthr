require "rails_helper"

# Spec 14, block 14b (D-670): the AI reads a platform type's document before the review and
# the review shows each field beside the record (RN-14-020 to RN-14-024, RN-08-021); the HR
# chooses what goes to the record, never the name, the CPF or the birth date (D-670). The AI
# off sends it straight to the review (CA-14-003); the API down marks "falha da IA" after the
# new tries, without credits (CA-14-004).
RSpec.describe "Document extraction", type: :request do
  include ActiveJob::TestHelper

  let(:company) { create(:company, name: "Metalúrgica Serra Azul") }
  let(:brand) { create(:brand, owner: company, commercial_name: "Serra Azul RH") }
  let!(:hr_admin) { enable_mfa(create(:user, name: "Juliana Ribeiro", cpf: "98765432100")) }
  let(:position) { create_position(company) }
  let(:profile) do
    register_employee(company, by: hr_admin, position: position, name: "Rafael Moura Campos", cpf: "52998224725",
      birth_date: Date.new(1990, 5, 20))
  end

  before do
    travel_to Time.zone.local(2026, 11, 10, 10)
    create(:membership, user: hr_admin, organization: company, roles: %w[hr_admin])
    brand.subdomains.create!(slug: "serraazul")
    Flipper.enable(FeatureFlags::SIGN_IN)
    Flipper.enable(FeatureFlags::AI)
    configure_anthropic
    publish_platform_legal_documents
    load_platform_document_types
    host! "serraazul.painel.catalysthr.com.br"
    accept_legal_documents(hr_admin, brand)
    sign_in_with_mfa("98765432100", hr_admin)
    post "/confirm-password", params: { password: "Catalyst#2026", return_to: "/" }
  end

  after { travel_back }

  def in_company(&) = ActsAsTenant.with_tenant(company, &)

  def type(code) = PlatformDocumentType.find_by!(code: code)

  def upload(code)
    file = Rack::Test::UploadedFile.new(StringIO.new("%PDF-1.4\n%fictício\n"), "application/pdf", original_filename: "#{code}.pdf")
    post "/employees/#{profile.id}/documents", params: { upload: { document_type_id: type(code).id, files: [ file ] } }
    document = in_company { Document.find_by!(document_type: type(code)) }
    version = in_company { document.versions.sole }
    in_company do
      version.files.blobs.each { |blob| blob.file_scan.record!(Antivirus::Clamd::Result.new(signature: nil)) }
      perform_enqueued_jobs(only: Documents::ConsolidatePdfJob)
    end
    [ document, in_company { version.reload } ]
  end

  def read(version)
    in_company { perform_enqueued_jobs(only: Ai::ExtractDocumentJob) }
    in_company { version.reload }
  end

  def rg_answer(name: "RAFAEL MOURA CAMPOS", detected: "rg", flags: [], confidence: "high")
    { "detected_type" => detected, "flags" => flags, "fields" => [
      { "key" => "name", "value" => name, "page" => 1, "confidence" => confidence },
      { "key" => "rg_number", "value" => "12.345.678-9", "page" => 1, "confidence" => "high" },
      { "key" => "rg_issuer", "value" => "SSP", "page" => 1, "confidence" => "high" },
      { "key" => "rg_state", "value" => "rs", "page" => 1, "confidence" => "medium" },
      { "key" => "birth_date", "value" => "1990-05-20", "page" => 1, "confidence" => "high" },
      { "key" => "filiation", "value" => "Maria Moura e João Campos", "page" => 2, "confidence" => "low" },
      { "key" => "cpf", "value" => "529.982.247-25", "page" => 1, "confidence" => "high" }
    ] }
  end

  it "reads the RG, shows each field beside the record and applies only what the HR chose (CA-14-001, RN-08-021)" do
    stub_claude(rg_answer(name: "RAFAEL MOURA CAMPOS DA SILVA"))
    document, version = upload("rg")
    expect(version).to be_ai_processing

    get "/documents/#{document.id}"
    expect(response.body).to include("Em leitura pela IA")

    version = read(version)
    expect(version).to be_awaiting_review
    extraction = in_company { AiExtraction.sole }
    expect(extraction).to have_attributes(status: "succeeded", profile_code: "rg", detected_type_code: "rg", ai_request: AiRequest.sole)
    expect(extraction.value("cpf")).to eq("52998224725")
    expect(extraction.value("rg_state")).to eq("RS")
    expect(ActiveRecord::Base.connection.select_value("SELECT fields FROM ai_extractions")).not_to include("RAFAEL")
    expect(AiRequest.sole).to have_attributes(feature: "document_extraction", prompt_version: "document_extraction-1", credits: 1,
      subject_id: version.id)

    get "/documents/#{document.id}"
    body = response.body
    expect(body).to include("Campos lidos pela IA", "RAFAEL MOURA CAMPOS DA SILVA", "Rafael Moura Campos", "confiança baixa, confira",
      "A IA não confirma a autenticidade")
    expect(body).to match(/data-ai-field="name" data-ai-status="divergent"/)
    expect(body).to match(/data-ai-field="cpf" data-ai-status="matches"/)
    expect(body).to match(/data-ai-field="birth_date" data-ai-status="matches"/)
    expect(body).to match(/data-ai-field="rg_number" data-ai-status="new"/)
    expect(body).not_to include("12.345.678-9")
    expect(body).not_to include('name="apply[]" value="name"')

    get "/documents/#{document.id}", params: { reveal: "documents" }
    expect(response.body).to include("12.345.678-9", 'value="rg_number"')

    patch "/documents/#{document.id}/versions/#{version.id}/approve",
      params: { apply: %w[rg_number rg_state name], values: { rg_number: "12.345.678-9", rg_state: "RS", rg_issuer: "SSP" } }
    expect(flash[:notice]).to eq("Versão aprovada.")
    in_company do
      expect(profile.reload).to have_attributes(rg_number: "123456789", rg_state: "RS", rg_issuer: nil)
      expect(profile.user.reload.name).to eq("Rafael Moura Campos")
      expect(version.reload).to be_approved
    end
  end

  it "asks the password before applying a document's number" do
    stub_claude(rg_answer)
    document, version = upload("rg")
    read(version)
    travel 6.minutes

    patch "/documents/#{document.id}/versions/#{version.id}/approve", params: { apply: %w[rg_number], values: { rg_number: "123" } }
    expect(flash[:alert]).to include("Confirme a senha")
    expect(in_company { version.reload }).to be_awaiting_review
  end

  it "points out another type than the asked one and the visual signs (CA-14-002, RN-14-023)" do
    stub_claude({ "detected_type" => "cnh", "flags" => %w[wrong_type screen_photo], "fields" => [
      { "key" => "holder_name", "value" => "Rafael Moura Campos", "page" => 1, "confidence" => "high" },
      { "key" => "postal_code", "value" => "95010-000", "page" => 1, "confidence" => "high" },
      { "key" => "issued_on", "value" => "2026-01-02", "page" => 1, "confidence" => "high" }
    ] })
    stub_request(:get, "https://viacep.com.br/ws/95010000/json/").to_return(body: { erro: true }.to_json)
    stub_request(:get, "https://brasilapi.com.br/api/cep/v2/95010000").to_return(status: 404, body: "{}")
    document, version = upload("proof_of_address")
    read(version)

    get "/documents/#{document.id}"
    expect(response.body).to include("Tipo diferente do pedido: o arquivo parece ser CNH.", "Parece uma foto de uma tela",
      "CEP não encontrado no ViaCEP.", "Emitido há mais tempo do que o tipo aceita", 'value="2026-01-02"')
    expect(response.body).to match(/data-ai-field="holder_name" data-ai-status="matches"/)
  end

  it "compares with the person's other approved documents (RN-14-022)" do
    stub_claude(rg_answer)
    document, version = upload("rg")
    read(version)
    patch "/documents/#{document.id}/versions/#{version.id}/approve"

    stub_claude({ "detected_type" => "cpf", "flags" => [], "fields" => [
      { "key" => "cpf", "value" => "52998224725", "page" => 1, "confidence" => "high" },
      { "key" => "name", "value" => "Rafael M. Campos", "page" => 1, "confidence" => "high" },
      { "key" => "birth_date", "value" => "1990-05-21", "page" => 1, "confidence" => "high" }
    ] })
    other, other_version = upload("cpf")
    read(other_version)
    get "/documents/#{other.id}"
    expect(response.body).to include("Divergência com RG, já aprovado: Nome e Data de nascimento.")
  end

  it "goes straight to the review without a call when the reading is off (CA-14-003)" do
    in_company { CompanyAiSetting.create!(feature: "document_extraction", enabled: false) }
    _document, version = upload("rg")
    expect(version).to be_awaiting_review
    expect(enqueued_jobs.map { |job| job[:job] }).not_to include(Ai::ExtractDocumentJob)
    expect(AiRequest.count).to eq(0)
    expect(AiCreditEntry.count).to eq(0)
  end

  it "keeps a company's own type and a published document out of the reading (RN-14-025)" do
    in_company { DocumentType.create!(name: "Crachá", category: "personal") }
    file = Rack::Test::UploadedFile.new(StringIO.new("%PDF-1.4\n"), "application/pdf", original_filename: "cracha.pdf")
    post "/employees/#{profile.id}/documents", params: { upload: { document_type_id: in_company { DocumentType.find_by!(name: "Crachá").id }, files: [ file ] } }
    version = in_company { Document.sole.versions.sole }
    in_company do
      version.files.blobs.each { |blob| blob.file_scan.record!(Antivirus::Clamd::Result.new(signature: nil)) }
      perform_enqueued_jobs(only: Documents::ConsolidatePdfJob)
      expect(version.reload).to be_awaiting_review
    end
  end

  it "marks \"falha da IA\" after the new tries, without credits, and the HR processes it again (CA-14-004, RN-14-121)" do
    stub_claude(status: 529)
    document, version = upload("rg")
    in_company do
      4.times do
        job = enqueued_jobs.find { |queued| queued[:job] == Ai::ExtractDocumentJob }
        enqueued_jobs.delete(job)
        ActiveJob::Base.execute(job)
      end
    end
    version = in_company { version.reload }
    expect(version).to be_ai_failed
    expect(in_company { AiExtraction.sole }).to have_attributes(status: "failed", failed_reason: "http_529", attempts: 4)
    expect(AiRequest.failed.count).to eq(4)
    expect(AiCreditEntry.count).to eq(0)

    get "/documents"
    expect(response.body).to include("Rafael Moura Campos")
    get "/documents/#{document.id}"
    expect(response.body).to include("Falha da IA", "Processar de novo")

    stub_claude(rg_answer)
    post "/documents/#{document.id}/versions/#{version.id}/reprocess"
    expect(flash[:notice]).to include("vai ler o documento de novo")
    expect(in_company { version.reload }).to be_ai_processing
    expect(read(version)).to be_awaiting_review
    expect(AiCreditEntry.sum(:credits)).to eq(1)
  end

  it "sends the version to the review when the company reaches the cap, and waits while the queue is paused (CA-14-012, RN-14-123)" do
    stub_claude(rg_answer)
    _document, version = upload("rg")
    AiDailyCap.create!(company: company, date: Date.current, cap_credits: 1, used_credits: 1, paused_at: Time.current)
    expect(read(version)).to be_awaiting_review
    expect(AiRequest.count).to eq(0)
  end
end
