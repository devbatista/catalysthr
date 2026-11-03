require "rails_helper"

# Spec 08, block 08c (RN-08-060 to RN-08-063, RN-08-082, RN-08-083, D-644): the batch's
# screens, the deletion and the recovery by the HR administrator, and the folder's ZIP
# behind the password, served only to who asked it.
RSpec.describe "Document batches, ZIP and deletion", type: :request do
  include ActiveJob::TestHelper

  let(:company) { create(:company, name: "Metalúrgica Serra Azul") }
  let(:brand) { create(:brand, owner: company, commercial_name: "Serra Azul RH") }
  let!(:hr_admin) { enable_mfa(create(:user, name: "Juliana Ribeiro", cpf: "98765432100")) }
  let(:position) { create_position(company) }
  let(:profile) { register_employee(company, by: hr_admin, position: position, name: "Marcos Teles") }

  before do
    travel_to Time.zone.local(2026, 11, 4, 10)
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

  def pdf_upload(name = "aso.pdf")
    Rack::Test::UploadedFile.new(StringIO.new("%PDF-1.4\n%fake\n"), "application/pdf", original_filename: name)
  end

  def clean(blobs)
    in_company { Array(blobs).each { |blob| blob.file_scan.record!(Antivirus::Clamd::Result.new(signature: nil)) } }
  end

  it "creates a batch, adds files, confirms one and distributes it (RN-08-060 to RN-08-063)" do
    profile
    post "/document-batches"
    batch = in_company { DocumentBatch.sole }
    expect(response).to redirect_to("/document-batches/#{batch.id}")

    post "/document-batches/#{batch.id}/files", params: { files: [ pdf_upload("aso-1.pdf"), pdf_upload("aso-2.pdf") ] }
    expect(flash[:notice]).to eq("2 arquivos acrescentados.")
    first, second = in_company { batch.items.to_a }
    clean([ first.file.blob, second.file.blob ])

    get "/document-batches/#{batch.id}"
    expect(response.body).to include("aso-1.pdf", "aso-2.pdf", "Marcos Teles", "ASO periódico", "Distribuir confirmados")

    patch "/document-batches/#{batch.id}/items", params: { items: {
      first.id => { document_type_id: type("aso_periodic").id, worker_profile_id: profile.id, status: "confirmed" },
      second.id => { status: "discarded" }
    } }
    expect(flash[:notice]).to eq("Escolhas salvas.")

    post "/document-batches/#{batch.id}/distribute"
    expect(flash[:notice]).to eq("1 arquivo distribuído.")
    expect(in_company { batch.reload }).to be_distributed
    expect(in_company { Document.sole }).to have_attributes(worker_profile_id: profile.id, source: "batch")

    get "/document-batches"
    expect(response.body).to include("Lotes", "2 arquivos · 1 distribuídos", "Distribuído")
  end

  it "lets the HR administrator delete with a reason and recover it (RN-08-083, CA-08-010)" do
    document = in_company do
      form = Documents::Upload.new(worker_profile: profile, document_type: DocumentType.find_by!(code: "school_statement"), files: [ pdf_upload ],
        by: hr_admin)
      form.save
      form.document
    end

    delete "/documents/#{document.id}", params: { delete_reason: "Enviado na pasta errada" }
    expect(response).to redirect_to("/employees/#{profile.id}/documents?category=statements")
    get "/employees/#{profile.id}/documents?category=statements"
    expect(response.body).to include("Excluídos · 1", "Enviado na pasta errada", "Recuperar")
    get "/documents/#{document.id}"
    expect(response).to have_http_status(:not_found)

    patch "/documents/#{document.id}/restore"
    expect(response).to redirect_to("/documents/#{document.id}")
    expect(in_company { document.reload.deleted_at }).to be_nil
  end

  it "keeps the deletion to the HR administrator (P-03-19)" do
    analyst_user = enable_mfa(create(:user, name: "Paula Lima", cpf: "52998224725"))
    analyst = create(:membership, user: analyst_user, organization: company, roles: %w[hr_analyst], status: "active", enabled_modules: %w[documentos])
    Memberships::AssignUnits.call(membership: analyst, unit_ids: [ company.headquarters.id ], by: hr_admin)
    document = in_company { Document.create!(worker_profile: profile, document_type: DocumentType.find_by!(code: "school_statement")) }
    delete "/sign-out"
    accept_legal_documents(analyst_user, brand)
    sign_in_with_mfa("52998224725", analyst_user)

    delete "/documents/#{document.id}", params: { delete_reason: "Teste" }
    expect(response).to have_http_status(:forbidden)
  end

  it "makes the folder's ZIP behind the password and serves it only to who asked it (RN-08-082, P-08-21)" do
    in_company do
      form = Documents::Upload.new(worker_profile: profile, document_type: DocumentType.find_by!(code: "school_statement"), files: [ pdf_upload ],
        by: hr_admin)
      form.save
      clean(form.version.files.blobs)
      perform_enqueued_jobs(only: Documents::ConsolidatePdfJob)
      Documents::Review.new(form.version.reload, by: hr_admin).approve
    end

    post "/employees/#{profile.id}/documents/export"
    expect(response).to redirect_to(%r{/confirm-password\?return_to=%2Femployees%2F#{profile.id}%2Fdocuments})
    post "/confirm-password", params: { password: "Catalyst#2026", return_to: "/" }

    expect do
      post "/employees/#{profile.id}/documents/export"
    end.to change { AccessEvent.where(kind: "export", action: "document_folder_requested").count }.by(1)
    export = in_company { DocumentFolderExport.sole }
    perform_enqueued_jobs(only: Documents::ZipFolderJob)

    get "/employees/#{profile.id}/documents"
    expect(response.body).to include("ZIP pronto: baixar até", "/document-exports/#{export.id}/download")

    get "/document-exports/#{export.id}/download"
    expect(response.media_type).to eq("application/zip")
    expect(response.body.b).to start_with("PK")
    expect(response.headers["Cache-Control"]).to include("no-store")

    other = enable_mfa(create(:user, name: "Rui Costa", cpf: "11144477735"))
    create(:membership, user: other, organization: company, roles: %w[hr_admin])
    delete "/sign-out"
    accept_legal_documents(other, brand)
    sign_in_with_mfa("11144477735", other)
    get "/document-exports/#{export.id}/download"
    expect(response).to have_http_status(:forbidden)
  end
end
