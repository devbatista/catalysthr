require "rails_helper"

# Spec 06, block 06b-1 (RN-06-001 to RN-06-042, D-639): the models of process in the
# admin's library, the partner's panel and the company's Empresa → Modelos de processo.
RSpec.describe "Models of process", type: :request do
  let(:partner) { create(:partner, name: "Aurora Gestão de Pessoas") }
  let(:partner_brand) { create(:brand, owner: partner, commercial_name: "Aurora RH") }
  let(:company) { create(:company, partner: partner, name: "Padaria Pão Quente") }
  let(:library) { SharedProcessTemplate.create!(kind: "admission", name: "Admissão CLT padrão", status: "active") }

  before do
    Flipper.enable(FeatureFlags::SIGN_IN)
    publish_platform_legal_documents
    partner_brand.subdomains.create!(slug: "aurora")
    library.items.create!(position: 1, kind: "task", title: "Conferir documentos", responsible_role: "hr")
  end

  def sign_in_panel(roles, organization:, cpf: "98765432100")
    user = enable_mfa(create(:user, cpf: cpf))
    create(:membership, user: user, organization: organization, roles: roles)
    accept_legal_documents(user, partner_brand)
    sign_in_with_mfa(cpf, user)
    user
  end

  def in_company(&)
    ActsAsTenant.with_tenant(company, &)
  end

  describe "the CatalystHR library, in the admin (D-126)" do
    before { host! "admin.catalysthr.com.br" }

    def sign_in_admin(role)
      user = enable_mfa(create(:user, platform_role: role, cpf: "52998224725"))
      sign_in_with_mfa("52998224725", user)
    end

    it "lets the support build a model with its items and activate it" do
      sign_in_admin("support")

      get "/process-templates"
      expect(response.body).to include("Conteúdo", "Biblioteca de modelos", "Admissão CLT padrão")

      post "/process-templates", params: { process_template: { name: "Integração padrão", kind: "onboarding" } }
      template = SharedProcessTemplate.find_by!(name: "Integração padrão")
      expect(response).to redirect_to("/process-templates/#{template.id}")
      expect(template).to have_attributes(status: "draft", partner_id: nil)

      post "/process-templates/#{template.id}/items", params: { item: { kind: "approval", title: "Aprovação do gestor",
        responsible_role: "manager", due_anchor: "work_start", due_offset_days: "5", due_direction: "after", due_business_days: "1" } }
      expect(template.items.sole).to have_attributes(kind: "approval", due_offset_days: 5, due_business_days: true)

      get "/process-templates/#{template.id}"
      expect(response.body).to include("Aprovação do gestor", "Gestores do departamento", "5 dias úteis depois do início do trabalho")

      patch "/process-templates/#{template.id}/activate"
      expect(template.reload).to be_active
    end

    it "keeps the library's PDF without a company (D-640)" do
      sign_in_admin("support")

      post "/process-templates/#{library.id}/items", params: { item: { kind: "acknowledgement", title: "Código de conduta",
        responsible_role: "employee", material_file: Rack::Test::UploadedFile.new(StringIO.new("%PDF-1.4"), "application/pdf",
          original_filename: "conduta.pdf") } }

      material = SharedProcessTemplateMaterial.sole
      expect(material).to have_attributes(company_id: nil, version: 1, item: library.items.find_by!(kind: "acknowledgement"))
    end

    it "keeps the finance team out" do
      sign_in_admin("finance")

      get "/process-templates"
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "in the partner's panel" do
    before { host! "aurora.painel.catalysthr.com.br" }

    it "lets the administrator adopt the library, as an independent draft (D-232)" do
      sign_in_panel(%w[partner_admin], organization: partner)

      get "/partner/process-templates"
      expect(response.body).to include("Adotar um modelo", "Admissão CLT padrão", "Biblioteca CatalystHR")

      post "/partner/process-templates/adopt", params: { source_id: library.id }

      copy = SharedProcessTemplate.find_by!(partner: partner)
      expect(response).to redirect_to("/partner/process-templates/#{copy.id}")
      expect(copy).to have_attributes(status: "draft", source_template_id: library.id)
      expect(copy.items.map(&:title)).to eq([ "Conferir documentos" ])
    end

    it "lets the consultant only read, and nobody reach another partner's models" do
      own = SharedProcessTemplate.create!(partner: partner, kind: "admission", name: "Admissão Aurora")
      foreign = SharedProcessTemplate.create!(partner: create(:partner), kind: "admission", name: "Admissão de outro")
      sign_in_panel(%w[consultant], organization: partner)

      get "/partner/process-templates/#{own.id}"
      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include("Editar", "Incluir item")

      patch "/partner/process-templates/#{own.id}", params: { process_template: { name: "Mudado" } }
      expect(response).to have_http_status(:forbidden)
      get "/partner/process-templates/#{foreign.id}"
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "in the company, for the HR administrator (D-240)" do
    let(:brand) { create(:brand, owner: company, commercial_name: "Padaria RH") }
    let(:partners) { SharedProcessTemplate.create!(partner: partner, kind: "admission", name: "Admissão Aurora", status: "active") }

    before do
      host! "aurora.painel.catalysthr.com.br"
      sign_in_panel(%w[hr_admin], organization: company)
      post "/current-company", params: { company_id: company.id }
    end

    it "lists the partner's and the library's active models to adopt, and adopts one (P-06-01, P-06-02)" do
      partners
      SharedProcessTemplate.create!(partner: create(:partner), kind: "admission", name: "De outro parceiro", status: "active")
      SharedProcessTemplate.create!(kind: "admission", name: "Rascunho da biblioteca")

      get "/process-templates"
      expect(response.body).to include("Empresa", 'href="/process-templates"', "Admissão Aurora", "Admissão CLT padrão")
      expect(response.body).not_to include("De outro parceiro", "Rascunho da biblioteca")

      post "/process-templates/adopt", params: { source_id: partners.id }
      copy = in_company { ProcessTemplate.sole }
      expect(response).to redirect_to("/process-templates/#{copy.id}")
      expect(copy).to have_attributes(name: "Admissão Aurora", status: "draft", company_id: company.id)
    end

    it "refuses adopting another partner's model" do
      foreign = SharedProcessTemplate.create!(partner: create(:partner), kind: "admission", name: "De outro", status: "active")

      post "/process-templates/adopt", params: { source_id: foreign.id }
      expect(response).to have_http_status(:not_found)
    end

    it "builds items with conditions and dependencies, refusing a cycle (CA-06-002, CA-06-008)" do
      unit = in_company { Unit.create!(name: "Caxias") }
      template = in_company { ProcessTemplate.create!(kind: "admission", name: "Admissão") }

      post "/process-templates/#{template.id}/items", params: { item: { kind: "task", title: "RG validado", responsible_role: "hr" } }
      post "/process-templates/#{template.id}/items", params: { item: { kind: "forward", title: "Encaminhar à contabilidade",
        responsible_role: "hr", config: { validated_documents: "1", record: "0" }, conditions: { unit_ids: [ "", unit.id ] } } }
      first, second = in_company { template.items.reload.to_a }
      expect(second).to have_attributes(position: 2, config: { "validated_documents" => true, "record" => false },
        conditions: { "unit_ids" => [ unit.id ] })

      patch "/process-templates/#{template.id}/items/#{second.id}", params: { item: { title: "Encaminhar à contabilidade",
        depends_on_item_ids: [ "", first.id ] } }
      patch "/process-templates/#{template.id}/items/#{first.id}", params: { item: { title: "RG validado",
        depends_on_item_ids: [ "", second.id ] } }
      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("formam um ciclo")

      get "/process-templates/#{template.id}"
      expect(response.body).to include("Depende de: RG validado", "Unidade: Caxias")
    end

    it "builds a form item with record groups and free fields (RN-06-030)" do
      template = in_company { ProcessTemplate.create!(kind: "admission", name: "Admissão") }

      get "/process-templates/#{template.id}/items/new", params: { kind: "form" }
      expect(response.body).to include("Grupos da ficha", "Conta para pagamento", "Campos livres")

      post "/process-templates/#{template.id}/items", params: { item: { kind: "form", title: "Dados para o cadastro",
        responsible_role: "employee", config: { groups: [ "", "address", "bank_account" ] }, free_fields: "Tamanho do uniforme\n\n" } }
      expect(in_company { template.items.sole.config }).to eq("groups" => %w[address bank_account], "custom_field_keys" => [],
        "free_fields" => [ "Tamanho do uniforme" ])
    end

    it "moves and removes items, the dependents losing the dependency" do
      template = in_company { ProcessTemplate.create!(kind: "admission", name: "Admissão") }
      first, second = in_company do
        a = template.items.create!(position: 1, kind: "task", title: "A", responsible_role: "hr")
        [ a, template.items.create!(position: 2, kind: "task", title: "B", responsible_role: "hr", depends_on_item_ids: [ a.id ]) ]
      end

      patch "/process-templates/#{template.id}/items/#{second.id}/move", params: { direction: "up" }
      expect(in_company { template.items.reload.map(&:title) }).to eq(%w[B A])

      delete "/process-templates/#{template.id}/items/#{first.id}"
      expect(in_company { template.items.reload.map { |item| [ item.title, item.depends_on_item_ids ] } }).to eq([ [ "B", [] ] ])
    end

    it "marks the default of the kind and keeps an archived model read only (RN-06-002, RN-06-003)" do
      template = in_company { ProcessTemplate.create!(kind: "admission", name: "Admissão") }

      patch "/process-templates/#{template.id}/default"
      expect(flash[:alert]).to eq("Só um modelo ativo pode ser o padrão.")

      patch "/process-templates/#{template.id}/activate"
      patch "/process-templates/#{template.id}/default"
      expect(in_company { template.reload.is_default }).to be(true)

      patch "/process-templates/#{template.id}/archive"
      get "/process-templates/#{template.id}/edit"
      expect(response).to redirect_to("/process-templates/#{template.id}")
      post "/process-templates/#{template.id}/items", params: { item: { kind: "task", title: "Novo", responsible_role: "hr" } }
      expect(in_company { template.items.count }).to eq(0)
    end

    it "links a position to its own admission model (D-204, RN-06-003)" do
      CboOccupation.create!(code: "784205", title: "Alimentador de linha de produção")
      template = in_company { ProcessTemplate.create!(kind: "admission", name: "Admissão da fábrica", status: "active") }
      position = in_company { Position.create!(name: "Auxiliar de produção", cbo_code: "784205") }

      get "/positions/#{position.id}/edit"
      expect(response.body).to include("Modelo de admissão", "Admissão da fábrica", "Usar o padrão da empresa")

      patch "/positions/#{position.id}", params: { position: { name: "Auxiliar de produção", cbo_code: "784205",
        admission_template_id: template.id } }
      expect(in_company { position.reload.admission_template }).to eq(template)
      get "/positions/#{position.id}"
      expect(response.body).to include("Admissão da fábrica")
    end

    it "answers 404 for another company's model (RN-01-013)" do
      foreign = ActsAsTenant.with_tenant(create(:company)) { ProcessTemplate.create!(kind: "admission", name: "De outra") }

      get "/process-templates/#{foreign.id}"
      expect(response).to have_http_status(:not_found)
    end
  end

  # Block 06b-2 (RN-06-060, P-06-17, P-05-30, D-640): the acknowledgement's PDF, by
  # version, released only after the virus scan.
  describe "the acknowledgement's material, in the company" do
    let(:template) { in_company { ProcessTemplate.create!(kind: "admission", name: "Admissão") } }

    before do
      host! "aurora.painel.catalysthr.com.br"
      sign_in_panel(%w[hr_admin], organization: company)
      post "/current-company", params: { company_id: company.id }
    end

    def pdf(content = "%PDF-1.4 regulamento", name: "regulamento.pdf")
      Rack::Test::UploadedFile.new(StringIO.new(content), "application/pdf", original_filename: name)
    end

    def add_item(file)
      post "/process-templates/#{template.id}/items", params: { item: { kind: "acknowledgement", title: "Regulamento interno",
        responsible_role: "employee", material_file: file } }
    end

    def scanned(material, status)
      FileScan.find_by!(blob: material.file.blob).update!(status: status)
    end

    it "serves the PDF and lets the model be activated only once the scan releases it" do
      expect { add_item(pdf) }.to have_enqueued_job(Antivirus::ScanJob)
      item = in_company { template.items.sole }
      material = in_company { item.materials.sole }
      expect(material).to have_attributes(version: 1, scan_status: "scanning")

      get "/process-templates/#{template.id}"
      expect(response.body).to include("Sem material liberado", "Versão 1 em varredura")
      get "/process-templates/#{template.id}/materials/#{material.id}"
      expect(response).to have_http_status(:not_found)
      patch "/process-templates/#{template.id}/activate"
      expect(flash[:alert]).to include("material já liberado pela varredura de vírus: Regulamento interno")
      expect(in_company { template.reload }).to be_draft

      scanned(material, "clean")
      get "/process-templates/#{template.id}"
      expect(response.body).to include("Material: versão 1")
      get "/process-templates/#{template.id}/materials/#{material.id}"
      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("application/pdf")
      expect(response.headers["Cache-Control"]).to include("no-store")
      expect(response.body).to eq("%PDF-1.4 regulamento")
      patch "/process-templates/#{template.id}/activate"
      expect(in_company { template.reload }).to be_active
    end

    it "refuses a file that is not a PDF by its content, a large one, or none" do
      add_item(pdf("MZ executável", name: "regulamento.pdf"))
      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("precisa ser um arquivo PDF")

      stub_const("ProcessTemplateMaterialDefinition::MAX_SIZE", 10)
      add_item(pdf("%PDF-1.4 grande demais"))
      expect(response.body).to include("pode ter até 0 MB")

      add_item(nil)
      expect(response.body).to include("precisa de um arquivo PDF")
      expect(in_company { template.items.count }).to eq(0)
      expect(FileScan.count).to eq(0)
    end

    it "keeps the older versions, in use while the new one scans, and after the item is removed (P-06-17)" do
      add_item(pdf)
      item = in_company { template.items.sole }
      first = in_company { item.materials.sole }
      scanned(first, "clean")

      patch "/process-templates/#{template.id}/items/#{item.id}", params: { item: { title: "Regulamento interno",
        material_file: pdf("%PDF-1.4 regulamento novo") } }
      second = in_company { item.materials.find_by!(version: 2) }
      get "/process-templates/#{template.id}/items/#{item.id}/edit"
      expect(response.body).to include("Versão 1", "Versão 2", "Liberada", "Em varredura", "Enviar uma nova versão")

      scanned(second, "infected")
      get "/process-templates/#{template.id}"
      expect(response.body).to include("Material: versão 1", "Versão 2 recusada: vírus encontrado")

      delete "/process-templates/#{template.id}/items/#{item.id}"
      expect(in_company { ProcessTemplateMaterial.where(id: [ first.id, second.id ]).pluck(:process_template_item_id) }).to eq([ nil, nil ])
    end

    it "answers 404 for another company's PDF (RN-01-013)" do
      other = create(:company, partner: partner)
      foreign = ActsAsTenant.with_tenant(other) do
        item = ProcessTemplate.create!(kind: "admission", name: "De outra").items.create!(position: 1, kind: "acknowledgement",
          title: "Manual", responsible_role: "employee")
        blob = ActiveStorage::Blob.create_and_upload!(io: StringIO.new("%PDF"), filename: "m.pdf", content_type: "application/pdf")
        FileScan.create!(blob: blob, status: "clean")
        item.materials.create!(version: 1, uploaded_by: create(:user), file: blob)
      end

      get "/process-templates/#{template.id}/materials/#{foreign.id}"
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "in the company, for the HR analyst" do
    before do
      host! "aurora.painel.catalysthr.com.br"
      sign_in_panel(%w[hr_analyst], organization: company, cpf: "11144477735")
      post "/current-company", params: { company_id: company.id }
    end

    it "has no models of process (D-240)" do
      get "/process-templates"
      expect(response).to have_http_status(:forbidden)

      get "/"
      expect(response.body).not_to include('href="/process-templates"')
    end
  end
end
