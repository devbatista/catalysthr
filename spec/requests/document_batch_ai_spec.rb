require "rails_helper"

# Spec 14, block 14c (D-670, D-672): the AI reads each file of a batch without its type and
# suggests the type, and the system finds the person by the CPF or the name, only in the scope of
# who sent it, without the people's list going to the AI (RN-14-030, RN-14-031, CA-14-005). Nothing
# reaches a folder before the HR confirms (RN-08-060, CA-08-006), and distributing reuses the
# reading, without a new call nor new credits (RN-14-032).
RSpec.describe "Document batches with the AI", type: :request do
  include ActiveJob::TestHelper

  let(:company) { create(:company, name: "Metalúrgica Serra Azul") }
  let(:brand) { create(:brand, owner: company, commercial_name: "Serra Azul RH") }
  let!(:hr_admin) { enable_mfa(create(:user, name: "Juliana Ribeiro", cpf: "98765432100")) }
  let(:position) { create_position(company) }
  let!(:rafael) { register_employee(company, by: hr_admin, position: position, name: "Rafael Moura Campos", cpf: "52998224725") }
  let!(:ana) { register_employee(company, by: hr_admin, position: position, name: "Ana Paula de Souza", cpf: "11144477735") }
  let!(:marcos) { register_employee(company, by: hr_admin, position: position, name: "Marcos Teles") }

  before do
    travel_to Time.zone.local(2026, 11, 11, 10)
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
  end

  after { travel_back }

  def in_company(&) = ActsAsTenant.with_tenant(company, &)

  def type(code) = PlatformDocumentType.find_by!(code: code)

  # The reference the AI gets for a type in the call, for who sent the batch.
  def ref(code, user: hr_admin)
    types = in_company { Documents::BatchReading.types(CompanyAbility.new(user, company)) }
    Ai::Prompts::BatchClassification.references(types).find { |_ref, listed| listed.id == type(code).id }&.first
  end

  def answer(type_ref:, detected: "aso", name: nil, cpf: nil, confidence: "high", flags: [])
    fields = [ { "key" => "exam_type", "value" => "periódico", "page" => 1, "confidence" => "high" },
      { "key" => "aso_result", "value" => "apto", "page" => 1, "confidence" => "high" } ]
    fields << { "key" => "name", "value" => name, "page" => 1, "confidence" => "high" } if name
    fields << { "key" => "cpf", "value" => cpf, "page" => 1, "confidence" => "high" } if cpf
    { "type_ref" => type_ref, "type_confidence" => confidence, "detected_type" => detected, "fields" => fields, "flags" => flags }
  end

  def new_batch(*names)
    post "/document-batches"
    batch = in_company { DocumentBatch.sole }
    files = names.map do |name|
      Rack::Test::UploadedFile.new(StringIO.new("%PDF-1.4\n%fictício\n"), "application/pdf", original_filename: name)
    end
    post "/document-batches/#{batch.id}/files", params: { files: files }
    [ batch, in_company { batch.items.to_a } ]
  end

  def clean(item)
    in_company { item.file.blob.file_scan.record!(Antivirus::Clamd::Result.new(signature: nil)) }
  end

  # The file's scan ends and the AI reads it with the answer given.
  def read(item, data)
    stub_claude(data)
    clean(item)
    in_company { perform_enqueued_jobs(only: Ai::ClassifyBatchItemJob) }
    in_company { item.reload }
  end

  it "suggests the type and the person by the CPF, and by the name with the score, without sending the people (CA-14-005)" do
    batch, (by_cpf, by_name, unknown) = new_batch("aso-rafael.pdf", "aso-ana.pdf", "aso-ilegivel.pdf")

    by_cpf = read(by_cpf, answer(type_ref: ref("aso_periodic"), cpf: "529.982.247-25", name: "RAFAEL MOURA CAMPOS"))
    expect(by_cpf).to have_attributes(suggested_type_id: type("aso_periodic").id, type_confidence: "high", person_match: "cpf",
      suggested_worker_profile_id: rafael.id, confidence: 1, status: "pending")

    by_name = read(by_name, answer(type_ref: ref("aso_periodic"), name: "Ana Paula Souza", confidence: "medium"))
    expect(by_name).to have_attributes(person_match: "name", suggested_worker_profile_id: nil, status: "pending")
    expect(by_name.person_candidates.first).to include("id" => ana.id)
    expect(by_name.person_candidates.pluck("id")).not_to include(marcos.id)

    unknown = read(unknown, answer(type_ref: nil, detected: "other", flags: %w[illegible]))
    expect(unknown).to have_attributes(suggested_type: nil, person_match: "none", suggested_worker_profile_id: nil)

    # The AI never gets the people of the company: only the file and the types (P-14-09).
    expect(WebMock).not_to(have_requested(:post, AnthropicHelpers::MESSAGES_URL).with do |request|
      request.body.include?("Ana Paula de Souza") || request.body.include?("Marcos Teles") || request.body.include?("Rafael Moura")
    end)
    expect(WebMock).to have_requested(:post, AnthropicHelpers::MESSAGES_URL).with { |request|
      request.body.include?("ASO periódico") && JSON.parse(request.body).dig("output_config", "format", "schema", "properties", "type_ref")
    }.times(3)
    expect(in_company { AiRequest.where(feature: "batch_classification", prompt_version: "batch_classification-1").count }).to eq(3)

    get "/document-batches/#{batch.id}"
    body = response.body
    expect(body).to include("Tipo sugerido pela IA: ASO periódico", "confiança alta", "confiança média",
      "Pessoa encontrada pelo CPF do documento: Rafael Moura Campos.", "Nomes parecidos com o do documento",
      "Nome no documento: Ana Paula Souza.", "A IA não reconheceu o tipo.", "Nenhuma pessoa do seu escopo encontrada",
      "O documento está ilegível em alguma parte.")
    page = Nokogiri::HTML(body)
    expect(page.at_css("select[name='items[#{by_cpf.id}][worker_profile_id]'] option[selected]")["value"]).to eq(rafael.id)
    expect(page.at_css("select[name='items[#{by_cpf.id}][document_type_id]'] option[selected]")["value"]).to eq(type("aso_periodic").id)
    # Only the CPF preselects; the name alike comes first, for the HR to choose (D-672).
    expect(page.at_css("select[name='items[#{by_name.id}][worker_profile_id]'] option[selected]")).to be_nil
    expect(page.at_css("select[name='items[#{by_name.id}][worker_profile_id]'] optgroup option")["value"]).to eq(ana.id)

    # Nothing reaches a folder before the confirmation (CA-08-006).
    expect(in_company { Document.count }).to eq(0)
  end

  it "reuses the reading on distributing, without a new call nor new credits (RN-14-032)" do
    batch, (item,) = new_batch("aso.pdf")
    item = read(item, answer(type_ref: ref("aso_periodic"), cpf: "52998224725", name: "RAFAEL MOURA CAMPOS"))

    patch "/document-batches/#{batch.id}/items", params: { items: {
      item.id => { document_type_id: item.suggested_type_id, worker_profile_id: item.suggested_worker_profile_id, status: "confirmed" }
    } }
    post "/document-batches/#{batch.id}/distribute"
    expect(flash[:notice]).to eq("1 arquivo distribuído.")
    in_company { perform_enqueued_jobs(only: [ Documents::ConsolidatePdfJob, Ai::ExtractDocumentJob ]) }

    document = in_company { Document.sole }
    version = in_company { document.versions.sole }
    expect(version).to be_awaiting_review
    extraction = in_company { AiExtraction.sole }
    expect(extraction).to have_attributes(subject_type: "DocumentVersion", subject_id: version.id, profile_code: "aso", status: "succeeded")
    expect(extraction.fields.pluck("key")).to contain_exactly("exam_type", "aso_result", "name", "cpf")
    expect(in_company { AiRequest.count }).to eq(1)
    expect(in_company { AiCreditEntry.sum(:credits) }).to eq(1)

    post "/confirm-password", params: { password: "Catalyst#2026", return_to: "/" }
    get "/documents/#{document.id}"
    expect(response.body).to include("RAFAEL MOURA CAMPOS")
  end

  it "keeps only the fields of the type the HR chose, with the alert, when it is another profile (D-672)" do
    batch, (item,) = new_batch("cnh.pdf")
    data = answer(type_ref: ref("cnh"), detected: "cnh", cpf: "52998224725", name: "RAFAEL MOURA CAMPOS")
    data["fields"] << { "key" => "cnh_number", "value" => "01234567890", "page" => 1, "confidence" => "high" }
    item = read(item, data)

    patch "/document-batches/#{batch.id}/items", params: { items: {
      item.id => { document_type_id: type("rg").id, worker_profile_id: rafael.id, status: "confirmed" }
    } }
    post "/document-batches/#{batch.id}/distribute"
    in_company { perform_enqueued_jobs(only: [ Documents::ConsolidatePdfJob, Ai::ExtractDocumentJob ]) }

    extraction = in_company { AiExtraction.sole }
    expect(extraction).to have_attributes(profile_code: "rg", detected_type_code: "cnh")
    expect(extraction.fields.pluck("key")).to contain_exactly("name", "cpf")
    expect(in_company { AiRequest.count }).to eq(1)

    post "/confirm-password", params: { password: "Catalyst#2026", return_to: "/" }
    get "/documents/#{in_company { Document.sole.id }}"
    expect(response.body).to include("data-ai-alert=\"wrong_type\"")
  end

  it "deletes what the AI read from the discarded files with the batch (RN-08-062)" do
    batch, (kept, dropped) = new_batch("aso.pdf", "outro.pdf")
    kept = read(kept, answer(type_ref: ref("aso_periodic"), cpf: "52998224725"))
    dropped = read(dropped, answer(type_ref: nil, detected: "other", name: "RAFAEL MOURA CAMPOS"))

    patch "/document-batches/#{batch.id}/items", params: { items: {
      kept.id => { document_type_id: type("aso_periodic").id, worker_profile_id: rafael.id, status: "confirmed" },
      dropped.id => { status: "discarded" }
    } }
    post "/document-batches/#{batch.id}/distribute"

    expect(in_company { batch.reload }).to be_distributed
    expect(in_company { AiExtraction.pluck(:subject_type) }).to eq(%w[DocumentVersion])
  end

  it "keeps a file the AI is still reading in the batch (D-672)" do
    batch, (item,) = new_batch("aso.pdf")
    clean(item)
    expect(in_company { item.reload.ai_extraction }).to be_queued

    patch "/document-batches/#{batch.id}/items", params: { items: {
      item.id => { document_type_id: type("aso_periodic").id, worker_profile_id: rafael.id, status: "confirmed" }
    } }
    get "/document-batches/#{batch.id}"
    expect(response.body).to include("A IA está lendo 1 arquivo.", "Em leitura pela IA")

    post "/document-batches/#{batch.id}/distribute"
    expect(flash[:notice]).to eq("Nenhum arquivo confirmado e liberado para distribuir.")
    expect(in_company { Document.count }).to eq(0)

    # The HR's choice stays: the reading only fills the suggestions.
    stub_claude(answer(type_ref: ref("aso_admission"), cpf: "11144477735"))
    in_company { perform_enqueued_jobs(only: Ai::ClassifyBatchItemJob) }
    expect(in_company { item.reload }).to have_attributes(status: "confirmed", confirmed_worker_profile_id: rafael.id,
      confirmed_type_id: type("aso_periodic").id, suggested_worker_profile_id: ana.id)
    post "/document-batches/#{batch.id}/distribute"
    expect(flash[:notice]).to eq("1 arquivo distribuído.")
  end

  it "leaves the files to the HR without a call when the distribution is off" do
    in_company { CompanyAiSetting.create!(feature: "batch_classification", enabled: false) }
    _batch, (item,) = new_batch("aso.pdf")
    clean(item)

    expect(in_company { item.reload.ai_extraction }).to be_nil
    expect(WebMock).not_to have_requested(:post, AnthropicHelpers::MESSAGES_URL)
  end

  it "marks \"falha da IA\" after the new tries, without credits, for the HR to choose by hand (RN-14-120)" do
    batch, (item,) = new_batch("aso.pdf")
    stub_claude(status: 500)
    clean(item)
    in_company do
      4.times do
        job = enqueued_jobs.find { |queued| queued[:job] == Ai::ClassifyBatchItemJob }
        enqueued_jobs.delete(job)
        ActiveJob::Base.execute(job)
      end
    end

    expect(in_company { item.reload.ai_extraction }).to have_attributes(status: "failed", failed_reason: "http_500")
    expect(in_company { AiRequest.failed.count }).to eq(4)
    expect(in_company { AiCreditEntry.count }).to eq(0)
    get "/document-batches/#{batch.id}"
    expect(response.body).to include("Falha da IA", "A IA não conseguiu ler este arquivo.")
  end

  it "suggests only the people of the analyst's units (RN-14-031, RN-03-006)" do
    branch = in_company { Unit.create!(name: "Filial Bento") }
    paula = register_employee(company, by: hr_admin, position: position, name: "Paula Bento Lima", cpf: "39053344705", unit: branch)
    analyst_user = enable_mfa(create(:user, name: "Carla Nunes", cpf: "86288366757"))
    analyst = create(:membership, user: analyst_user, organization: company, roles: %w[hr_analyst], status: "active", enabled_modules: %w[documentos])
    Memberships::AssignUnits.call(membership: analyst, unit_ids: [ company.headquarters.id ], by: hr_admin)
    delete "/sign-out"
    accept_legal_documents(analyst_user, brand)
    sign_in_with_mfa("86288366757", analyst_user)

    _batch, (by_cpf, by_name) = new_batch("aso-1.pdf", "aso-2.pdf")
    by_cpf = read(by_cpf, answer(type_ref: ref("aso_periodic", user: analyst_user), cpf: "39053344705", name: "XYZ"))
    by_name = read(by_name, answer(type_ref: ref("aso_periodic", user: analyst_user), name: "Paula Bento Lima"))

    expect(by_cpf).to have_attributes(person_match: "none", suggested_worker_profile_id: nil)
    expect(by_name.person_candidates.pluck("id")).not_to include(paula.id)
  end
end
