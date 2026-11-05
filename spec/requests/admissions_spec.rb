require "rails_helper"

# Spec 07, block 07a (RN-07-001 to RN-07-022, D-648): the admission in the panel, for the HR
# and the client manager (spec 03, sections 4.4 and 4.12).
RSpec.describe "Admissions", type: :request do
  include ActiveJob::TestHelper

  let(:partner) { create(:partner) }
  let(:partner_brand) { create(:brand, owner: partner, commercial_name: "Aurora RH") }
  let(:company) { create(:company, partner: partner, name: "Padaria Pão Quente", uses_allocation_clients: true) }
  let(:hr_user) { create(:user, name: "Juliana Ribeiro", cpf: "52998224725") }
  let!(:hr) { create(:membership, user: hr_user, organization: company, roles: %w[hr_admin]) }
  let(:position) { create_position(company, name: "Motorista") }
  let(:unit) { company.headquarters }
  let(:department) { in_company { Department.create!(name: "Produção", unit: unit) } }
  let(:start) { Date.current + 10 }
  let!(:template) do
    in_company do
      model = ProcessTemplate.create!(kind: "admission", name: "Admissão padrão")
      model.items.create!(position: 1, kind: "task", title: "Conferir o cadastro", responsible_role: "hr", stage: "registration")
      model.items.create!(position: 2, kind: "forward", title: "Encaminhar à contabilidade", responsible_role: "hr",
        config: { "record" => true })
      model.update!(status: "active")
      model.make_default!
      model
    end
  end

  before do
    Flipper.enable(FeatureFlags::SIGN_IN)
    Flipper.enable(FeatureFlags::ADMISSIONS)
    publish_platform_legal_documents
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

  def admission_params(**overrides)
    { name: "Rafael Campos", cpf: "11144477735", mobile_phone: "54999990000", kind: "clt", category: "standard",
      started_on: start.iso8601, position_id: position.id, unit_id: unit.id, department_id: department.id }.merge(overrides)
  end

  def create_admission(**overrides)
    post "/admissions", params: { admission: admission_params(**overrides) }
    in_company { Admission.order(:created_at).last }
  end

  def admit(by: hr, **attributes)
    in_company do
      registration = AdmissionRegistration.new(admission_params(**attributes))
      raise registration.errors.full_messages.to_sentence unless registration.save(company: company.reload, by: by.user, starter: by)

      registration.admission
    end
  end

  describe "the initial registration" do
    before { sign_in_member(hr) }

    it "creates it with the minimum data and no invitation (CA-07-001, RN-07-012)" do
      admission = nil
      expect { admission = create_admission }.not_to have_enqueued_job(Invitations::DeliverJob)

      in_company do
        employment = admission.employment
        expect(employment).to be_pending
        expect(employment.revisions.sole).to have_attributes(position_id: position.id, salary_cents: nil, reason: "admission")
        expect(employment.worker_profile.membership).to have_attributes(status: "invited", invitation_token_digest: nil)
        expect(admission.process_instance).to have_attributes(kind: "admission", status: "open")
        expect(admission.process_instance.anchor_date("work_start")).to eq(start)
        expect(admission).to have_attributes(source: "manual", esocial_status: "not_sent", aso_status: "missing")
        expect(admission).not_to be_released
      end
      expect(AccessEvent.find_by!(action: "admission_created").subject_id).to eq(admission.id)
      expect(response).to redirect_to("/admissions/#{admission.id}")
    end

    it "leaves the esocial out for a contractor (RN-07-050)" do
      expect(create_admission(kind: "contractor", category: nil).esocial_status).to eq("not_applicable")
    end

    it "refuses a start in the past, which goes through Novo colaborador (D-648)" do
      post "/admissions", params: { admission: admission_params(started_on: (Date.current - 1).iso8601) }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("hoje ou uma data futura")
    end

    it "asks for an e-mail or a mobile phone and for the department (RN-07-011)" do
      post "/admissions", params: { admission: admission_params(mobile_phone: "", department_id: "") }

      expect(response.body).to include("Informe o e-mail ou o celular")
      expect(in_company { Admission.count }).to eq(0)
    end

    it "keeps the client on the first revision, and the client's managers see it (CA-07-013, P-07-19)" do
      client = in_company { AllocationClient.create!(name: "Cliente X") }

      admission = create_admission(allocation_client_id: client.id)

      expect(in_company { admission.employment.revisions.sole.allocation_client_id }).to eq(client.id)
    end

    it "reuses the person's record and warns about the other employment, without blocking (RN-07-014, RN-07-012)" do
      profile = register_employee(company, by: hr_user, position: position, cpf: "11144477735", started_on: Date.current - 30)

      admission = create_admission

      expect(in_company { admission.worker_profile.id }).to eq(profile.id)
      expect(flash[:notice]).to include("já tem cadastro")
      follow_redirect!
      expect(response.body).to include("Esta pessoa já tem vínculo")
    end

    it "says what to do when no model serves (RN-07-013)" do
      in_company { template.archive! }

      post "/admissions", params: { admission: admission_params }

      expect(response.body).to include("Nenhum modelo de admissão ativo")
    end

    it "takes the next registration number and doesn't ask for it" do
      expect(in_company { create_admission.employment.registration_number }).to eq(company.suggested_registration_number.to_i.pred.to_s)
    end
  end

  describe "the choice of the model (RN-07-013, P-07-04)" do
    let(:other) do
      in_company { ProcessTemplate.create!(kind: "admission", name: "Admissão de estágio", status: "active") }
    end

    it "goes by the position, then the employment kind, then the default" do
      own = in_company { ProcessTemplate.create!(kind: "admission", name: "Admissão de motorista", status: "active") }
      in_company do
        other.make_default_for!(%w[intern])
        position.update!(admission_template: own)

        expect(Admissions.template_for(position_id: position.id, kind: "intern")).to eq(own)
        position.update!(admission_template: nil)
        expect(Admissions.template_for(position_id: position.id, kind: "intern")).to eq(other)
        expect(Admissions.template_for(position_id: position.id, kind: "clt")).to eq(template)
      end
    end

    it "gives each employment kind one model: marking takes it from the previous (D-648)" do
      in_company do
        template.make_default_for!(%w[clt intern])
        other.make_default_for!(%w[intern])

        expect(template.reload.default_employment_kinds).to eq(%w[clt])
        expect(other.reload.default_employment_kinds).to eq(%w[intern])
      end
    end

    it "lets the HR mark the kinds on the model's page" do
      sign_in_member(hr)

      patch "/process-templates/#{template.id}/default-kinds", params: { employment_kinds: [ "", "clt", "other" ] }

      expect(in_company { template.reload.default_employment_kinds }).to eq(%w[clt])
    end

    it "loses the kinds when archived" do
      in_company do
        template.make_default_for!(%w[clt])
        template.archive!

        expect(template.reload.default_employment_kinds).to be_empty
      end
    end

    it "includes the model of the position and the document it requires (CA-07-002, RN-06-037)" do
      cnh = in_company { DocumentType.create!(name: "CNH do motorista", category: "personal") }
      own = in_company do
        ProcessTemplate.create!(kind: "admission", name: "Admissão de motorista").tap do |model|
          model.items.create!(position: 1, kind: "task", title: "Teste de direção", responsible_role: "hr")
          model.update!(status: "active")
          position.update!(admission_template: model)
          position.required_document_types << cnh
        end
      end
      admission = admit

      in_company do
        expect(admission.process_instance.template).to eq(own)
        item = admission.process_instance.items.find_by!(title: "CNH do motorista")
        expect(item).to have_attributes(kind: "document", responsible_role: "employee", stage: "documents", required: true,
          status: "pending", config: { "document_type_id" => cnh.id })
      end
    end

    it "doesn't repeat a required document already in the model (RN-06-037)" do
      cnh = in_company { DocumentType.create!(name: "CNH do motorista", category: "personal") }
      in_company do
        template.items.create!(position: 3, kind: "document", title: "Sua CNH", responsible_role: "employee",
          config: { "document_type_id" => cnh.id })
        position.required_document_types << cnh
      end

      expect(in_company { admit.process_instance.items.where(kind: "document").pluck(:title) }).to eq([ "Sua CNH" ])
    end
  end

  describe "the steps (RN-07-002, RN-07-003)" do
    it "hides the accounting step and its items without it (CA-07-011)" do
      admission = admit

      in_company do
        expect(admission.steps).to eq(%w[registration documents ai hr_review conclusion])
        expect(admission.process_instance.items.pluck(:title)).to eq([ "Conferir o cadastro" ])
      end
    end

    it "has six steps and the forward with it" do
      company.update!(uses_accounting_step: true)
      admission = admit

      in_company do
        expect(admission.steps.size).to eq(6)
        expect(admission.process_instance.items.find_by!(kind: "forward").stage).to eq("accounting")
      end
    end

    it "shows the first step with a required item pending, never the AI's (RN-07-002, RN-07-004)" do
      admission = admit

      in_company do
        item = admission.process_instance.items.sole
        expect(admission.current_step).to eq("registration")
        item.update!(status: "done")
        expect(Admission.find(admission.id).current_step).to eq("conclusion")
      end
    end

    it "gives a new item of the editor its step by the kind (RN-07-001)" do
      in_company do
        expect(template.items.find_by!(kind: "forward").stage).to eq("accounting")
        expect(template.items.create!(position: 3, kind: "acknowledgement", title: "Regimento", responsible_role: "employee",
          material_uploaded_by: hr_user).stage).to eq("documents")
      end
    end
  end

  describe "changing the model (RN-07-013, D-648)" do
    let(:other) do
      in_company do
        type = DocumentType.create!(name: "Comprovante", category: "personal")
        ProcessTemplate.create!(kind: "admission", name: "Outra admissão").tap do |model|
          model.items.create!(position: 1, kind: "document", title: "Comprovante", responsible_role: "employee",
            config: { "document_type_id" => type.id })
          model.update!(status: "active")
        end
      end
    end

    before { sign_in_member(hr) }

    it "cancels the old process with the history and starts a new one" do
      admission = admit
      previous = admission.process_instance

      patch "/admissions/#{admission.id}/template", params: { process_template_id: other.id }

      in_company do
        expect(previous.reload).to have_attributes(status: "cancelled", cancel_reason: "Modelo trocado")
        expect(admission.reload.process_instance.template).to eq(other)
      end
      expect(flash[:notice]).to eq("Modelo trocado.")
    end

    it "resolves the item whose type already has an approved document (D-648)" do
      admission = admit
      in_company do
        type = DocumentType.find(other.items.sole.config["document_type_id"])
        pdf = Rack::Test::UploadedFile.new(StringIO.new("%PDF-1.4 teste"), "application/pdf", original_filename: "comprovante.pdf")
        form = Documents::Upload.new(worker_profile: admission.worker_profile, document_type: type, files: [ pdf ], by: hr_user)
        form.save
        form.version.files.each { |file| file.blob.file_scan.record!(Antivirus::Clamd::Result.new(signature: nil)) }
        perform_enqueued_jobs(only: Documents::ConsolidatePdfJob)
        Documents::Review.new(form.version.reload, by: hr_user).approve
      end

      patch "/admissions/#{admission.id}/template", params: { process_template_id: other.id }

      in_company { expect(admission.reload.process_instance.items.sole.status).to eq("approved") }
    end

    it "refuses after the access is released" do
      admission = admit
      in_company { admission.update!(invite_released_at: Time.current, invite_released_by: hr_user) }

      patch "/admissions/#{admission.id}/template", params: { process_template_id: other.id }

      expect(flash[:alert]).to include("não pode ser trocado")
      in_company { expect(admission.reload.process_instance.template).to eq(template) }
    end
  end

  describe "releasing the access (RN-07-020, D-252)" do
    before { sign_in_member(hr) }

    it "sends the 72-hour invitation by the link and the e-mail (CA-07-003 without WhatsApp)" do
      admission = admit(email: "rafael@example.com")

      expect { post "/admissions/#{admission.id}/release", params: { channels: %w[email link] } }
        .to have_enqueued_job(Invitations::DeliverJob).once

      expect(response.body).to include("Enviamos o convite para rafael@example.com", "Link para entregar em mãos")
      in_company do
        admission.reload
        expect(admission).to have_attributes(invite_released_by_id: hr_user.id)
        expect(admission).to be_released
        expect(admission.worker_profile.membership.invitation_expires_at).to be_within(1.minute).of(72.hours.from_now)
      end
      expect(AccessEvent.find_by!(action: "admission_access_released").subject_id).to eq(admission.id)
    end

    it "asks for a channel" do
      admission = admit

      post "/admissions/#{admission.id}/release"

      expect(flash[:alert]).to include("ao menos um canal")
      in_company { expect(admission.reload).not_to be_released }
    end

    it "only notifies who already has access (spec 15, D-648)" do
      person = create(:user, cpf: "11144477735", name: "Rafael Campos")
      create(:membership, user: person, organization: company, roles: %w[manager])
      admission = admit

      expect { post "/admissions/#{admission.id}/release" }.not_to have_enqueued_job(Invitations::DeliverJob)

      expect(flash[:notice]).to eq("Acesso liberado.")
      expect(Notification.find_by!(recipient_user: person).notification_type).to eq("admission.started")
    end

    it "keeps the person out of the portal's mass invitation until released (D-252, D-648)" do
      admit(email: "rafael@example.com")

      expect { post "/employees/invite" }.not_to have_enqueued_job(Invitations::DeliverJob)
    end

    it "takes the record's invitation to the admission while it waits (D-252, D-648)" do
      admission = admit(email: "rafael@example.com")
      profile = in_company { admission.worker_profile }

      post "/employees/#{profile.id}/invite", params: { channels: %w[email] }

      expect(response).to redirect_to("/admissions/#{admission.id}")
      expect(flash[:alert]).to include("libere o acesso")
    end
  end

  describe "the start" do
    before { sign_in_member(hr) }

    it "moves the employment, the first revision and the items' dates (RN-06-027)" do
      in_company { template.items.find_by!(title: "Conferir o cadastro").update!(due_anchor: "work_start", due_offset_days: -2) }
      admission = admit
      moved = start + 5

      patch "/admissions/#{admission.id}/start-date", params: { started_on: moved.iso8601 }

      in_company do
        admission.reload
        expect(admission.employment.started_on).to eq(moved)
        expect(admission.employment.revisions.sole.effective_on).to eq(moved)
        expect(admission.process_instance.items.sole.due_on).to eq(moved - 2)
      end
    end

    it "refuses a date in the past" do
      admission = admit

      patch "/admissions/#{admission.id}/start-date", params: { started_on: (Date.current - 1).iso8601 }

      expect(flash[:alert]).to include("hoje ou uma data futura")
    end

    it "lets the HR complete the salary of a pending employment starting today (RN-07-011)" do
      in_company do
        revision = admit(started_on: Date.current.iso8601).employment.revisions.sole

        expect(revision).to be_changeable
        expect(revision.update(salary_cents: 250_000)).to be(true)
      end
    end
  end

  describe "the process's page" do
    it "doesn't end nor cancel an admission, which has its own rules (RN-07-080, RN-07-090)" do
      sign_in_member(hr)
      admission = admit
      id = in_company { admission.process_instance_id }

      patch "/processes/#{id}/cancel", params: { cancel_reason: "Teste" }

      expect(response).to redirect_to("/admissions/#{admission.id}")
      in_company { expect(admission.reload.process_instance).to be_open }
    end
  end

  describe "the scopes (spec 03, section 4.4)" do
    let(:other_unit) { in_company { Unit.create!(name: "Filial") } }
    let(:analyst_user) { create(:user, cpf: "39053344705", name: "Ana Analista") }
    let!(:analyst) do
      create(:membership, user: analyst_user, organization: company, roles: %w[hr_analyst], enabled_modules: %w[admissao]).tap do |membership|
        in_company { MembershipUnit.create!(membership: membership, unit: unit) }
      end
    end

    it "keeps the analyst in their units (U scope)" do
      elsewhere = in_company { Department.create!(name: "Filial", unit: other_unit) }
      sign_in_member(analyst)

      post "/admissions", params: { admission: admission_params(unit_id: other_unit.id, department_id: elsewhere.id) }

      expect(response).to have_http_status(:forbidden)
      expect(in_company { Admission.count }).to eq(0)
    end

    it "doesn't open it to an analyst without the module (M)" do
      analyst.update!(enabled_modules: [])
      sign_in_member(analyst)

      get "/admissions"

      expect(response).to have_http_status(:forbidden)
    end

    it "lets the analyst without the payroll module complete the salary of the admission only (RN-07-011, D-648)" do
      admission = admit
      revision = in_company { admission.employment.revisions.sole }
      active = register_employee(company, by: hr_user, position: position, department: department)
      other = in_company { active.employments.sole.revisions.sole }
      sign_in_member(analyst)

      get "/admissions/#{admission.id}"
      expect(response.body).to include("Completar salário e jornada")

      get "/employments/#{revision.employment_id}/revisions/#{revision.id}/edit"
      expect(response).to redirect_to(%r{/confirm-password})
      post "/confirm-password", params: { password: "Catalyst#2026", return_to: "/admissions" }
      patch "/employments/#{revision.employment_id}/revisions/#{revision.id}",
        params: { employment_revision: { effective_on: revision.effective_on.iso8601, position_id: position.id, unit_id: unit.id,
          department_id: department.id, salary: "2.500,00", salary_unit: "month" } }
      expect(in_company { revision.reload.salary_cents }).to eq(250_000)

      get "/employments/#{revision.employment_id}/revisions/#{revision.id}/edit"
      expect(response.body).to include("2.500,00")
      expect(AccessEvent.where(kind: "sensitive_read", user: analyst_user, field: "salary_cents")).to exist

      get "/employments/#{other.employment_id}/revisions/#{other.id}/edit"
      expect(response).to have_http_status(:forbidden)
    end

    it "lets the consultant of the company operate every unit (CA-03-004)" do
      consultant_user = create(:user, cpf: "16899535009", name: "Clara Consultora")
      consultant = create(:membership, user: consultant_user, organization: partner, roles: %w[consultant], enabled_modules: %w[admissao solicitacoes])
      PartnerMembershipCompany.create!(membership: consultant, company: company)
      sign_in_member(consultant)

      get "/admissions/new"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Nova admissão")
      ability = ActsAsTenant.with_tenant(company) { CompanyAbility.new(consultant_user, company) }
      expect(ability.can?(:admit_in, other_unit)).to be(true)
      expect(ability.can?(:use_module, :folha)).to be(false)
    end
  end

  describe "the client manager (P-07-20, spec 03, section 4.12)" do
    let(:client_x) { in_company { AllocationClient.create!(name: "Cliente X") } }
    let(:client_y) { in_company { AllocationClient.create!(name: "Cliente Y") } }
    let(:manager_user) { create(:user, cpf: "39053344705", name: "Marcos Cliente") }
    let!(:manager) do
      create(:membership, user: manager_user, organization: company, roles: %w[client_manager]).tap do |membership|
        in_company { AllocationClientManager.create!(allocation_client: client_x, membership: membership) }
      end
    end

    before do
      in_company do
        template.items.create!(position: 3, kind: "approval", title: "Aprovação do gestor do cliente", responsible_role: "client_manager")
      end
    end

    it "sees the step and their items, without documents nor salary (CA-03-011, CA-07-013)" do
      admission = admit(allocation_client_id: client_x.id)
      sign_in_member(manager)

      get "/admissions"
      expect(response.body).to include("Rafael Campos")

      get "/admissions/#{admission.id}"

      expect(response.body).to include("Rafael Campos", "Aprovação do gestor do cliente", "Etapa atual")
      expect(response.body).not_to include("Conferir o cadastro", "Liberar acesso", "Abrir a ficha", "salário")
    end

    it "gets 404 for an admission of another client (CA-03-010)" do
      admission = admit(allocation_client_id: client_y.id)
      sign_in_member(manager)

      get "/admissions/#{admission.id}"

      expect(response).to have_http_status(:not_found)
    end

    it "sends the item to the HR, with an alert, without a client (CA-07-014, RN-06-022)" do
      admission = admit
      sign_in_member(hr)

      in_company do
        item = admission.process_instance.items.find_by!(title: "Aprovação do gestor do cliente")
        expect(item).to have_attributes(responsible_fallback: true, responsible_membership_ids: [ hr.id ])
      end
      get "/admissions/#{admission.id}"
      expect(response.body).to include("foi para o RH")
    end
  end

  describe "the flag (D-648)" do
    before do
      Flipper.disable(FeatureFlags::ADMISSIONS)
      sign_in_member(hr)
    end

    it "answers 404 and keeps Em breve in the menu" do
      get "/admissions"
      expect(response).to have_http_status(:not_found)

      get "/"
      expect(response.body).to include("Em breve")
    end
  end

  describe "the screens this block touches" do
    before { sign_in_member(hr) }

    it "opens the model's page with the kinds and the item's form with the step (RN-07-001, RN-07-013)" do
      get "/process-templates/#{template.id}"
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Padrão por tipo de vínculo", "Cadastro inicial")

      get "/process-templates/#{template.id}/items/new", params: { kind: "task" }
      expect(response.body).to include("Etapa da admissão")
    end

    it "saves the documents a position requires on its form (RN-04-030)" do
      cnh = in_company { DocumentType.create!(name: "CNH do motorista", category: "personal") }

      get "/positions/#{position.id}/edit"
      expect(response.body).to include("Documentos exigidos", "CNH do motorista")

      patch "/positions/#{position.id}", params: { position: { name: "Motorista", cbo_code: position.cbo_code, required_document_type_ids: [ "", cnh.id ] } }

      expect(in_company { position.reload.required_document_type_ids }).to eq([ cnh.id ])
      follow_redirect!
      expect(response.body).to include("CNH do motorista")
    end

    it "turns the accounting step on in the settings (D-258)" do
      get "/settings/edit"
      expect(response.body).to include("Usar a etapa de contabilidade na admissão")

      patch "/settings", params: { company: { uses_accounting_step: "1" } }

      expect(company.reload.uses_accounting_step).to be(true)
    end

    it "shows the admission on the person's record while the access waits (D-252)" do
      admission = admit
      get "/employees/#{in_company { admission.worker_profile.id }}"

      expect(response.body).to include("Esta pessoa está em admissão", "/admissions/#{admission.id}")
    end

    it "opens the list, the form and the process with the way back to the admission" do
      admission = admit

      get "/admissions"
      expect(response.body).to include("Rafael Campos", "Cadastro inicial", "0 de 1")
      get "/admissions/new"
      expect(response.body).to include("Nova admissão")
      get "/processes/#{in_company { admission.process_instance_id }}"
      expect(response.body).to include("Abrir a admissão")
      expect(response.body).not_to include("Cancelar processo")
    end
  end

  it "leaves Em breve when the flag is on (D-598)" do
    sign_in_member(hr)

    get "/admissions"

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('href="/admissions"')
    expect(response.body).not_to include("coming-soon/admissions")
  end
end
