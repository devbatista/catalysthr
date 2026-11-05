require "rails_helper"

# Spec 07, block 07c (RN-07-040 to RN-07-043, CA-07-004, D-650): the models of contracts and
# terms, the PDF in the process and the signed one in the folder.
RSpec.describe "Contracts and terms", type: :request do
  include ActiveJob::TestHelper

  let(:partner) { create(:partner) }
  let(:partner_brand) { create(:brand, owner: partner, commercial_name: "Aurora RH") }
  let(:company) { create(:company, partner: partner, name: "Padaria Pão Quente", legal_name: "Pão Quente Ltda") }
  let(:hr_user) { create(:user, name: "Juliana Ribeiro", cpf: "52998224725") }
  let!(:hr) { create(:membership, user: hr_user, organization: company, roles: %w[hr_admin]) }
  let(:position) { create_position(company, name: "Padeiro") }
  let(:department) { in_company { Department.create!(name: "Produção", unit: company.headquarters) } }
  let!(:model) do
    in_company do
      ProcessTemplate.create!(kind: "admission", name: "Admissão padrão").tap do |process_model|
        process_model.items.create!(position: 1, kind: "task", title: "Conferir", responsible_role: "hr")
        process_model.update!(status: "active")
        process_model.make_default!
      end
    end
  end
  let(:template) do
    in_company do
      DocumentTemplate.create!(name: "Contrato CLT", employment_kinds: %w[clt], body: <<~TEXT)
        # Contrato de trabalho

        A empresa {{empresa.razao_social}} contrata **{{colaborador.nome}}**, CPF {{colaborador.cpf}}, como {{cargo.nome}}.
        Salário: {{vinculo.salario}}.

        - Primeira cláusula
        - Segunda cláusula

        | Campo | Valor |
        | Matrícula | {{vinculo.matricula}} |
      TEXT
    end
  end
  let(:admission) do
    in_company do
      registration = AdmissionRegistration.new(name: "Rafael Campos", cpf: "11144477735", email: "rafael@example.com", kind: "clt",
        category: "standard", started_on: Date.current + 10, position_id: position.id, unit_id: company.headquarters.id, department_id: department.id)
      raise registration.errors.full_messages.to_sentence unless registration.save(company: company.reload, by: hr_user, starter: hr)

      registration.admission
    end
  end
  let(:employment) { in_company { admission.employment } }

  before do
    Flipper.enable(FeatureFlags::SIGN_IN)
    Flipper.enable(FeatureFlags::ADMISSIONS)
    publish_platform_legal_documents
    load_platform_document_types
    partner_brand.subdomains.create!(slug: "aurora")
    host! "aurora.painel.catalysthr.com.br"
  end

  def in_company(&)
    ActsAsTenant.with_tenant(company, &)
  end

  def sign_in_member(membership)
    user = enable_mfa(membership.user)
    accept_legal_documents(user, partner_brand)
    sign_in_with_mfa(user.cpf, user)
    post "/current-company", params: { company_id: company.id }
  end

  def confirm_password
    post "/confirm-password", params: { password: "Catalyst#2026", return_to: "/admissions" }
  end

  def fill_salary
    in_company { employment.revisions.sole.update!(salary_cents: 250_000) }
  end

  def generate(**params)
    post "/admissions/#{admission.id}/contracts", params: { document_template_id: template.id, **params }
  end

  def generated
    in_company { GeneratedDocument.find_by!(employment_id: employment.id, document_template_id: template.id) }
  end

  describe "the models (RN-07-040, RN-07-041, P-07-17)" do
    it "lets the HR administrator keep them, and shows the toolbar and the variables" do
      sign_in_member(hr)

      get "/document-templates/new"
      expect(response.body).to include("Inserir variável", "Vínculo: salário", "data-wrap")

      post "/document-templates", params: { document_template: { name: "Termo", body: "Olá {{colaborador.nome}}", employment_kinds: [ "", "intern" ] } }

      saved = in_company { DocumentTemplate.find_by!(name: "Termo") }
      expect(saved).to have_attributes(employment_kinds: %w[intern], variables: %w[colaborador.nome], status: "active")
    end

    it "refuses a variable outside the catalog (D-650)" do
      sign_in_member(hr)

      post "/document-templates", params: { document_template: { name: "Termo", body: "Olá {{colaborador.apelido}}", employment_kinds: %w[clt] } }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("variáveis que não existem", "colaborador.apelido")
    end

    it "refuses a character the PDF's font doesn't have, saying which, and takes Portuguese and Word's quotes (D-650)" do
      in_company do
        bad = DocumentTemplate.new(name: "Termo", body: "Assinatura ✓", employment_kinds: %w[clt])
        expect(bad).not_to be_valid
        expect(bad.errors[:body].sole).to include("✓")
        expect(DocumentTemplate.new(name: "Termo", body: "Ação, coração – “aspas” e ‘apóstrofo’ § º", employment_kinds: %w[clt])).to be_valid
      end
    end

    it "shows the preview in PDF with the variables' names" do
      template
      sign_in_member(hr)

      get "/document-templates/#{template.id}/preview"

      expect(response.media_type).to eq("application/pdf")
      expect(response.headers["Cache-Control"]).to include("no-store")
      expect(response.body).to start_with("%PDF")
    end

    it "is closed to the HR analyst, who only uses them (P-07-17)" do
      user = create(:user, cpf: "39053344705")
      analyst = create(:membership, user: user, organization: company, roles: %w[hr_analyst], enabled_modules: %w[admissao])
      sign_in_member(analyst)

      get "/document-templates"

      expect(response).to have_http_status(:forbidden)
    end

    it "shows in the company's menu and answers 404 with the flag off (D-648)" do
      sign_in_member(hr)
      get "/document-templates"
      expect(response.body).to include("Modelos de contrato")

      Flipper.disable(FeatureFlags::ADMISSIONS)
      get "/document-templates"
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "the PDF" do
    it "renders every piece of the markup in a valid PDF" do
      pdf = Documents::ContractPdf.new(title: "Contrato", body: "# T\n\n## S\n\n**b** e *i*\n\n- a\n1. b\n| x | y |\n|---|---|\n| 1 | 2 |",
        values: {}).render

      expect(pdf).to start_with("%PDF")
    end

    it "never lets a value become formatting (D-650)" do
      rendered = Documents::ContractPdf.new(title: "C", body: "Nome: {{colaborador.nome}}", values: { "colaborador.nome" => "<b>Ana</b> **x** & cia" })
      expect(rendered.send(:inline, "Nome: {{colaborador.nome}}")).to eq("Nome: &lt;b&gt;Ana&lt;/b&gt; **x** &amp; cia")
    end

    it "turns a blank value into a line to fill in by hand (RN-07-042)" do
      rendered = Documents::ContractPdf.new(title: "C", body: "x", values: { "vinculo.salario" => "" })
      expect(rendered.send(:inline, "{{vinculo.salario}}")).to eq(Documents::ContractPdf::BLANK)
    end

    it "reads the variables from the record, the employment and the company" do
      fill_salary
      in_company do
        employment.reload
        values = Documents::TemplateVariables.new(employment).values
        expect(values).to include("colaborador.nome" => "Rafael Campos", "colaborador.cpf" => "111.444.777-35", "cargo.nome" => "Padeiro",
          "vinculo.salario" => "R$ 2.500,00", "empresa.razao_social" => "Pão Quente Ltda", "vinculo.inicio" => I18n.l(Date.current + 10))
        expect(values.keys).to match_array(Documents::TemplateVariables::CATALOG)
      end
    end
  end

  describe "generating (RN-07-042, CA-07-004)" do
    before { sign_in_member(hr) }

    it "warns about the blank variable and generates only with the confirmation (CA-07-004)" do
      generate

      expect(response.body).to include("Há campos em branco", "Vínculo: salário", "Gerar com campo em branco")
      expect(in_company { GeneratedDocument.count }).to eq(0)

      expect { generate(confirm_blank: "1") }.to have_enqueued_job(Documents::GenerateFromTemplateJob)
      expect(generated).to have_attributes(status: "generating", missing_variables: %w[vinculo.salario], generated_by_id: hr_user.id)
    end

    it "generates at once without blanks, in the process and out of the folder (RN-07-043, D-650)" do
      fill_salary

      perform_enqueued_jobs(only: Documents::GenerateFromTemplateJob) { generate }

      expect(generated).to be_ready
      in_company do
        expect(generated.file.download).to start_with("%PDF")
        expect(generated.file.blob.key).to start_with("companies/#{company.id}/documents/")
        expect(Document.where(worker_profile_id: employment.worker_profile_id)).to be_empty
      end
      expect(response).to redirect_to("/admissions/#{admission.id}#contracts")
    end

    it "offers only the models of the employment kind (RN-07-040)" do
      intern = in_company { DocumentTemplate.create!(name: "Termo de estágio", employment_kinds: %w[intern], body: "x") }

      post "/admissions/#{admission.id}/contracts", params: { document_template_id: intern.id }

      expect(response).to have_http_status(:not_found)
      template
      get "/admissions/#{admission.id}"
      expect(response.body).to include("Contrato CLT")
      expect(response.body).not_to include("Termo de estágio")
    end

    it "stops on a value the font doesn't have, instead of a silent question mark (D-650)" do
      in_company { employment.worker_profile.user.update!(name: "Nguyễn Văn An") }
      fill_salary

      generate

      expect(flash[:alert]).to include("caracteres que o PDF não aceita", "ễ")
      expect(in_company { GeneratedDocument.count }).to eq(0)
    end

    it "replaces the PDF not signed, keeping one record (D-650)" do
      fill_salary
      perform_enqueued_jobs(only: Documents::GenerateFromTemplateJob) { generate }
      first = in_company { generated.file.blob.id }

      perform_enqueued_jobs(only: Documents::GenerateFromTemplateJob) { generate }

      in_company do
        expect(GeneratedDocument.where(employment_id: employment.id).count).to eq(1)
        expect(generated.file.blob.id).not_to eq(first)
        expect(ActiveStorage::Blob.exists?(first)).to be(false)
      end
    end

    it "runs again without repeating (idempotent job)" do
      fill_salary
      perform_enqueued_jobs(only: Documents::GenerateFromTemplateJob) { generate }
      blob = in_company { generated.file.blob.id }

      in_company { Documents::GenerateFromTemplateJob.perform_now(generated) }

      in_company { expect(generated.file.blob.id).to eq(blob) }
    end

    it "marks a failure instead of leaving it generating" do
      fill_salary
      generate
      in_company do
        allow(Documents::ContractPdf).to receive(:new).and_raise(Prawn::Errors::IncompatibleStringEncoding)
        Documents::GenerateFromTemplateJob.perform_now(generated)
      end

      expect(generated).to be_failed
    end
  end

  describe "opening the PDF (D-650)" do
    before do
      sign_in_member(hr)
      fill_salary
      perform_enqueued_jobs(only: Documents::GenerateFromTemplateJob) { generate }
    end

    it "asks for the password, doesn't cache it and records the access (RN-02-052, RN-05-020)" do
      get "/admissions/#{admission.id}/contracts/#{generated.id}"
      expect(response).to redirect_to(%r{/confirm-password})

      confirm_password
      get "/admissions/#{admission.id}/contracts/#{generated.id}"

      expect(response.media_type).to eq("application/pdf")
      expect(response.headers["Cache-Control"]).to include("no-store")
      expect(AccessEvent.find_by!(action: "generated_document_opened").subject_id).to eq(generated.id)
    end

    it "opens for the analyst of the open admission, without the payroll module (D-650)" do
      delete "/sign-out"
      user = create(:user, cpf: "39053344705")
      analyst = create(:membership, user: user, organization: company, roles: %w[hr_analyst], enabled_modules: %w[admissao])
      in_company { MembershipUnit.create!(membership: analyst, unit: company.headquarters) }
      sign_in_member(analyst)
      confirm_password

      get "/admissions/#{admission.id}/contracts/#{generated.id}"

      expect(response.media_type).to eq("application/pdf")
    end

    it "answers 403 once the admission is closed, without the pay permission (D-650)" do
      delete "/sign-out"
      user = create(:user, cpf: "39053344705")
      analyst = create(:membership, user: user, organization: company, roles: %w[hr_analyst], enabled_modules: %w[admissao])
      in_company do
        MembershipUnit.create!(membership: analyst, unit: company.headquarters)
        admission.process_instance.update!(status: "completed", completed_at: Time.current, completed_by: hr_user)
      end
      sign_in_member(analyst)
      confirm_password

      get "/admissions/#{admission.id}/contracts/#{generated.id}"

      expect(response).to have_http_status(:forbidden)
    end

    it "keeps it from the client manager (RN-03-014, P-07-20)" do
      delete "/sign-out"
      company.update!(uses_allocation_clients: true)
      user = create(:user, cpf: "39053344705")
      manager = create(:membership, user: user, organization: company, roles: %w[client_manager])
      sign_in_member(manager)

      get "/admissions/#{admission.id}/contracts/#{generated.id}"

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "the signed version (RN-07-043)" do
    let(:signed_file) { Rack::Test::UploadedFile.new(StringIO.new("%PDF-1.4\n%fake\n"), "application/pdf", original_filename: "assinado.pdf") }

    before do
      sign_in_member(hr)
      fill_salary
      perform_enqueued_jobs(only: Documents::GenerateFromTemplateJob) { generate }
    end

    it "goes to the folder as a sensitive 'Contrato assinado', and blocks generating again until removed (D-650)" do
      patch "/admissions/#{admission.id}/contracts/#{generated.id}/signed", params: { files: [ signed_file ] }

      expect(flash[:notice]).to include("Versão assinada enviada")
      in_company do
        document = generated.signed_document
        expect(document.document_type).to have_attributes(code: "signed_contract", category: "admission")
        expect(document).to be_sensitive
        expect(document.worker_profile_id).to eq(employment.worker_profile_id)
      end

      generate
      expect(flash[:alert]).to include("já tem a versão assinada")

      in_company { generated.signed_document.update!(deleted_at: Time.current, deleted_by: hr_user, delete_reason: "Errado") }
      generate
      expect(flash[:notice]).to include("Gerando")
    end

    it "answers the item that asks for it" do
      type = DocumentType.unscoped.find_by!(code: "signed_contract")
      item = in_company do
        admission.process_instance.items.create!(position: 9, kind: "document", title: "Contrato assinado", status: "pending",
          responsible_role: "hr", responsible_membership_ids: [ hr.id ], config: { "document_type_id" => type.id })
      end

      patch "/admissions/#{admission.id}/contracts/#{generated.id}/signed", params: { files: [ signed_file ] }

      in_company { expect(generated.signed_document.process_item).to eq(item) }
    end

    it "refuses a file that isn't a PDF or an image" do
      bad = Rack::Test::UploadedFile.new(StringIO.new("texto"), "text/plain", original_filename: "a.txt")

      patch "/admissions/#{admission.id}/contracts/#{generated.id}/signed", params: { files: [ bad ] }

      expect(flash[:alert]).to be_present
      expect(generated.signed_document_id).to be_nil
    end
  end

  it "shows the contracts on the admission only to the HR" do
    template
    sign_in_member(hr)

    get "/admissions/#{admission.id}"

    expect(response.body).to include("Contratos e termos", "Gerar documento")
  end
end
