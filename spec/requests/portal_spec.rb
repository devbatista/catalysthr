require "rails_helper"

# Spec 16, block 16a (RN-16-001 to RN-16-031, RN-08-012, RN-08-051, RN-06-060, D-645): the
# employee's and the manager's portal, the start by profile, the folder with the uploads
# and the acknowledgment, the process items, "Minha equipe", the notices and the HR's
# invitation.
RSpec.describe "Portal", type: :request do
  include ActiveJob::TestHelper

  let(:company) { create(:company, name: "Metalúrgica Serra Azul") }
  let(:brand) { create(:brand, owner: company, commercial_name: "Serra Azul RH") }
  let!(:hr_user) { enable_mfa(create(:user, name: "Juliana Ribeiro", cpf: "98765432100")) }
  let!(:hr) { create(:membership, user: hr_user, organization: company, roles: %w[hr_admin]) }
  let(:position) { create_position(company) }
  let(:manager_user) { create(:user, name: "Carlos Mendes", cpf: "11144477735") }
  let!(:manager) { create(:membership, user: manager_user, organization: company, roles: %w[manager]) }
  let(:department) { in_company { Department.create!(name: "Produção", unit: company.headquarters).tap { |each| each.managers << manager } } }
  let(:profile) { register_employee(company, by: hr_user, position: position, name: "Rafael Moura Campos", department: department) }

  before do
    travel_to Time.zone.local(2026, 11, 4, 10)
    brand.subdomains.create!(slug: "serraazul")
    Flipper.enable(FeatureFlags::SIGN_IN)
    publish_platform_legal_documents
    load_platform_document_types
    host! "serraazul.painel.catalysthr.com.br"
  end

  after { travel_back }

  def in_company(&) = ActsAsTenant.with_tenant(company, &)

  def type(code) = PlatformDocumentType.find_by!(code: code)

  def pdf_upload(content = "%PDF-1.4\n%fake\n", name = "doc.pdf")
    Rack::Test::UploadedFile.new(StringIO.new(content), "application/pdf", original_filename: name)
  end

  def clean(blobs)
    in_company do
      Array(blobs).each { |blob| blob.file_scan.record!(Antivirus::Clamd::Result.new(signature: nil)) }
      perform_enqueued_jobs(only: Documents::ConsolidatePdfJob)
    end
  end

  # The employee accepted the invitation (RN-02-014).
  def sign_in_employee(person = profile)
    user = person.user
    user.update!(password: "Catalyst#2026", password_confirmation: "Catalyst#2026")
    in_company { person.membership.update!(status: "active") }
    accept_legal_documents(user, brand)
    post "/sign-in", params: { user: { login: user.cpf, password: "Catalyst#2026" } }
  end

  def hr_document(code, person = profile, approve: true)
    in_company do
      form = Documents::Upload.new(worker_profile: person, document_type: DocumentType.find_by!(code: code), files: [ pdf_upload ], by: hr_user)
      form.save
      clean(form.version.files.blobs)
      Documents::Review.new(form.version.reload, by: hr_user).approve if approve
      form.document.reload
    end
  end

  describe "the start by profile (RN-16-002)" do
    it "sends who is only an employee to the portal, without the tabs that do not apply (CA-16-002)" do
      sign_in_employee
      get "/"
      expect(response).to redirect_to("/portal")

      get "/portal"
      expect(response.body).to include("Olá, Rafael", "Início", "Docs", "Mais", "Nenhuma pendência no momento.")
      expect(response.body).not_to include("Ponto", "Pedidos", "Abrir painel")
    end

    it "keeps the HR in the panel, with \"Meu portal\" for who is also an employee" do
      accept_legal_documents(hr_user, brand)
      sign_in_with_mfa("98765432100", hr_user)
      get "/"
      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include("Meu portal")

      in_company { hr.update!(roles: %w[hr_admin employee]) }
      get "/"
      expect(response.body).to include("Meu portal", 'href="/portal"')
    end

    it "shows the manager \"Minha equipe\" and \"Abrir painel\" (RN-16-030, RN-16-031)" do
      member = profile
      in_company do
        template = ProcessTemplate.create!(kind: "onboarding", name: "Integração")
        template.items.create!(position: 1, kind: "task", title: "Boas-vindas da equipe", responsible_role: "manager")
        template.update!(status: "active")
        Processes::Start.call(template: template.reload, employment: member.employments.sole, started_by: hr_user, starter: hr,
          anchors: { "work_start" => Date.current + 3 })
      end
      cnh = hr_document("cnh", member, approve: false)
      in_company { Documents::Review.new(cnh.latest_version, by: hr_user).approve(valid_until: Date.current + 10) }
      accept_legal_documents(manager_user, brand)
      enable_mfa(manager_user)
      sign_in_with_mfa("11144477735", manager_user)

      get "/"
      expect(response).to redirect_to("/portal")
      get "/portal"
      expect(response.body).to include("Minha equipe", "1 item de processo para você", "1 documento da equipe vencendo", "Abrir painel")

      get "/portal/team"
      expect(response.body).to include("Boas-vindas da equipe", "Rafael Moura Campos", "CNH de Rafael Moura Campos vence em 14/11/2026")
      expect(response.body).not_to include("/documents/#{cnh.id}")
      get "/?panel=1"
      expect(response).to have_http_status(:ok)
    end
  end

  describe "the folder (spec 08, RN-08-080, RN-08-081)" do
    it "shows only the version in force and never the internal types (D-274, D-280, CA-08-008)" do
      rg = hr_document("rg")
      second = in_company do
        form = Documents::Upload.new(document: rg, worker_profile: profile, files: [ pdf_upload("%PDF-1.4 v2") ], by: hr_user)
        form.save
        clean(form.version.files.blobs)
        form.version.reload
      end
      internal = in_company { DocumentType.create!(name: "Advertência interna", category: "statements", internal: true) }
      hr_document("rg").update_columns(document_type_id: internal.id)
      sign_in_employee

      get "/portal/documents"
      expect(response.body).to include("RG", "Em revisão")
      expect(response.body).not_to include("Advertência interna")

      get "/portal/documents/#{rg.id}"
      expect(response.body).to include("O seu envio está com o RH para conferência.", "Abrir o documento")
      get "/portal/documents/#{rg.id}/file"
      expect(response).to redirect_to(%r{/confirm-password})
      post "/confirm-password", params: { password: "Catalyst#2026", return_to: "/" }
      expect do
        get "/portal/documents/#{rg.id}/file"
      end.to change { AccessEvent.where(kind: "sensitive_read", user: profile.user).count }.by(1)
      expect(response.body).to eq("%PDF-1.4\n%fake\n")
      expect(response.body).not_to eq(second.pdf.download)
    end

    it "keeps the other person's documents out of reach (RN-03-006)" do
      other = register_employee(company, by: hr_user, position: position, name: "Lívia Prado")
      foreign = hr_document("rg", other)
      sign_in_employee

      get "/portal/documents/#{foreign.id}"
      expect(response).to have_http_status(:not_found)
      get "/documents/#{foreign.id}"
      expect(response).to have_http_status(:not_found)
    end

    it "sends a new document, which goes to the HR's review with the HR's notice (RN-08-013)" do
      sign_in_employee
      get "/portal/documents/new"
      expect(response.body).to include("Tirar foto", 'capture="environment"', "Escolher foto ou PDF", "RG")
      expect(response.body).not_to include("ASO periódico")

      post "/portal/documents", params: { upload: { document_type_id: type("rg").id, files: [ pdf_upload ] } }
      document = in_company { Document.sole }
      expect(response).to redirect_to("/portal/documents/#{document.id}")
      expect(document).to have_attributes(source: "employee", worker_profile_id: profile.id)
      expect(Notification.where(notification_type: "documents.review_pending", recipient_user: hr_user).count).to eq(1)

      # Health is sent only by the HR and the clinic (spec 03, section 4.5).
      post "/portal/documents", params: { upload: { document_type_id: type("aso_periodic").id, files: [ pdf_upload ] } }
      expect(response).to have_http_status(:unprocessable_content)
      expect(in_company { Document.count }).to eq(1)
    end

    it "shows the request and the correction as pending items, with the employee's notices, and takes the new version" do
      in_company { profile.membership.update!(status: "active") }
      request = in_company do
        form = Documents::RequestForm.new(document_type: DocumentType.find_by!(code: "school_statement"), due_on: Date.new(2026, 11, 20),
          audience_filter: { "worker_profile_ids" => [ profile.id ] }, message: "Do semestre", by: hr_user,
          ability: Ability.new(hr_user, area: :panel, company: company))
        form.save
        form.request
      end
      requested = in_company { request.targets.sole.document }
      expect(Notification.where(notification_type: "documents.requested", recipient_user: profile.user, path: "/portal/documents/#{requested.id}"))
        .to exist
      proof = hr_document("proof_of_address", profile, approve: false)
      in_company { Documents::Review.new(proof.latest_version, by: hr_user).request_correction(reason: "expired") }
      expect(Notification.where(notification_type: "documents.correction_requested", recipient_user: profile.user)).to exist
      sign_in_employee

      get "/portal"
      expect(response.body).to include("Pendências · 2", "Enviar Declaração escolar", "Do semestre", "até 20/11",
        "Corrigir Comprovante de residência", "Documento vencido")

      post "/portal/documents/#{proof.id}/versions", params: { upload: { files: [ pdf_upload ] } }
      expect(response).to redirect_to("/portal/documents/#{proof.id}")
      expect(in_company { proof.versions.count }).to eq(2)
      get "/portal"
      expect(response.body).to include("Pendências · 1")
    end

    it "records the acknowledgment with the IP, the browser and the hash (RN-08-051, CA-08-007)" do
      in_company { profile.membership.update!(status: "active") }
      publication = in_company do
        form = Documents::Publish.new(title: "Advertência de 04/11", document_type: DocumentType.find_by!(code: "school_statement"),
          file: pdf_upload("%PDF-1.4 advertencia"), audience_filter: { "worker_profile_ids" => [ profile.id ] }, due_on: Date.new(2026, 11, 9),
          by: hr_user, ability: Ability.new(hr_user, area: :panel, company: company))
        form.save
        form.publication
      end
      acknowledgment = in_company { publication.acknowledgments.sole }
      clean(in_company { acknowledgment.version.files.blobs })
      expect(Notification.where(notification_type: "documents.acknowledgment_pending", recipient_user: profile.user, mandatory: true)).to exist
      sign_in_employee

      get "/portal/documents/#{acknowledgment.document_id}"
      expect(response.body).to include("Advertência de 04/11", "Li e estou ciente", "não significa concordância nem assinatura")
      patch "/portal/acknowledgments/#{acknowledgment.id}/confirm", params: { comment: "Recebi" },
        headers: { "User-Agent" => "Safari no iPhone" }
      expect(flash[:notice]).to eq("Ciência registrada.")
      expect(in_company { acknowledgment.reload }).to have_attributes(status: "acknowledged", ip: "127.0.0.1", user_agent: "Safari no iPhone",
        comment: "Recebi", sha256: Digest::SHA256.hexdigest("%PDF-1.4 advertencia"))
      # The published document is the HR's: no version from the employee (D-643).
      get "/portal/documents/#{acknowledgment.document_id}"
      expect(response.body).to include("Você deu ciência em")
      expect(response.body).not_to include("Enviar uma nova versão")
      get "/portal/documents/#{acknowledgment.document_id}/versions/new"
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "the process items (RN-06-010, RN-06-060)" do
    let(:instance) do
      in_company do
        template = ProcessTemplate.create!(kind: "onboarding", name: "Integração")
        template.items.create!(position: 1, kind: "task", title: "Conhecer o refeitório", responsible_role: "employee")
        item = template.items.build(position: 2, kind: "acknowledgement", title: "Código de conduta", responsible_role: "employee",
          material_file: pdf_upload("%PDF-1.4 codigo", "codigo.pdf"), material_uploaded_by: hr_user)
        item.save!(context: :editor_create)
        clean(item.materials.sole.file.blob)
        template.items.create!(position: 3, kind: "document", title: "Enviar o RG", responsible_role: "employee",
          config: { "document_type_id" => DocumentType.find_by!(code: "rg").id })
        template.update!(status: "active")
        Processes::Start.call(template: template.reload, employment: profile.employments.sole, started_by: hr_user, starter: hr,
          anchors: { "work_start" => Date.current + 3 })
      end
    end

    def item(title) = in_company { instance.items.find_by!(title: title) }

    it "lets the employee do the task, read and accept the PDF, and send the document" do
      instance
      sign_in_employee
      get "/portal"
      expect(response.body).to include("Pendências · 3", "Conhecer o refeitório", "Código de conduta", "Enviar o RG", "Integração · 0 de 3")

      patch "/portal/items/#{item("Conhecer o refeitório").id}/done", params: { comment: "Feito" }
      expect(item("Conhecer o refeitório")).to be_done

      get "/portal/items/#{item("Código de conduta").id}"
      expect(response.body).to include("Ler o material (versão 1)", "Li e aceito")
      get "/portal/items/#{item("Código de conduta").id}/material"
      expect(response.body).to eq("%PDF-1.4 codigo")
      patch "/portal/items/#{item("Código de conduta").id}/acknowledge", headers: { "User-Agent" => "Chrome" }
      expect(item("Código de conduta")).to have_attributes(status: "done")
      expect(item("Código de conduta").result).to include("material_version" => 1, "ip" => "127.0.0.1", "user_agent" => "Chrome")

      get "/portal/items/#{item("Enviar o RG").id}"
      expect(response.body).to include("Enviar o documento", "process_item_id=#{item("Enviar o RG").id}")
      post "/portal/documents", params: { upload: { document_type_id: type("rg").id, process_item_id: item("Enviar o RG").id, files: [ pdf_upload ] } }
      expect(item("Enviar o RG")).to be_submitted

      get "/portal"
      expect(response.body).to include("Integração · 2 de 3")
    end

    it "keeps the items of someone else out of reach" do
      instance
      other = register_employee(company, by: hr_user, position: position, name: "Lívia Prado")
      sign_in_employee(other)

      get "/portal/items/#{item("Conhecer o refeitório").id}"
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "the HR's invitation (D-600, D-645)" do
    before do
      accept_legal_documents(hr_user, brand)
      sign_in_with_mfa("98765432100", hr_user)
    end

    it "invites from the record by e-mail or link" do
      get "/employees/#{profile.id}"
      expect(response.body).to include("Acesso ao portal", "Sem acesso", "Convidar para o portal", "Link ou QR code")

      post "/employees/#{profile.id}/invite", params: { channels: %w[link] }
      expect(response).to have_http_status(:ok)
      expect(in_company { profile.membership.reload }.invitation_open?).to be(true)
    end

    it "invites everyone without access by e-mail and lists who has no e-mail" do
      profile
      without = register_employee(company, by: hr_user, position: position, name: "Lívia Prado")
      without.user.update_columns(email: nil)

      expect do
        post "/employees/invite"
      end.to change { in_company { Membership.where.not(invitation_sent_at: nil).count } }.by(1)
      expect(response.body).to include("Enviado por e-mail · 1", "Rafael Moura Campos", "Sem e-mail válido · 1", "Lívia Prado")

      post "/employees/invite"
      expect(response.body).to include("Enviados por e-mail · 0")
    end
  end
end
