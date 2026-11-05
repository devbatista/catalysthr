require "rails_helper"

# Spec 07, block 07d-1 (RN-07-060, RN-07-061, RN-07-080 to RN-07-083, RN-07-090 to RN-07-092,
# RN-07-110 to RN-07-112, D-648, D-650, D-651): the ASO, the end of the admission, the
# onboarding and the cancellation.
RSpec.describe "Admission conclusion", type: :request do
  include ActiveJob::TestHelper

  let(:partner) { create(:partner) }
  let(:partner_brand) { create(:brand, owner: partner, commercial_name: "Aurora RH") }
  let(:company) { create(:company, partner: partner, name: "Padaria Pão Quente") }
  let(:hr_user) { create(:user, name: "Juliana Ribeiro", cpf: "52998224725") }
  let!(:hr) { create(:membership, user: hr_user, organization: company, roles: %w[hr_admin]) }
  let(:position) { create_position(company, name: "Padeiro") }
  let(:department) { in_company { Department.create!(name: "Produção", unit: company.headquarters) } }
  let(:start) { Date.current + 10 }
  let!(:onboarding) do
    in_company do
      ProcessTemplate.create!(kind: "onboarding", name: "Integração").tap do |model|
        model.items.create!(position: 1, kind: "task", title: "Boas-vindas", responsible_role: "employee")
        model.update!(status: "active")
      end
    end
  end
  let!(:template) do
    in_company do
      ProcessTemplate.create!(kind: "admission", name: "Admissão padrão", onboarding_template: onboarding).tap do |model|
        model.items.create!(position: 1, kind: "task", title: "Conferir", responsible_role: "hr")
        model.items.create!(position: 2, kind: "approval", title: "Aprovação", responsible_role: "hr")
        model.update!(status: "active")
        model.make_default!
      end
    end
  end
  let(:admission) { admit }
  let(:employment) { in_company { admission.employment } }
  let(:instance) { in_company { admission.process_instance } }
  let(:pdf) { Rack::Test::UploadedFile.new(StringIO.new("%PDF-1.4\n%fake\n"), "application/pdf", original_filename: "aso.pdf") }

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

  def admit(kind: "clt", cpf: "11144477735", **attributes)
    in_company do
      registration = AdmissionRegistration.new({ name: "Rafael Campos", cpf: cpf, email: "#{cpf}@example.com", kind: kind,
        category: kind == "clt" ? "standard" : nil, started_on: start, position_id: position.id, unit_id: company.headquarters.id,
        department_id: department.id }.merge(attributes))
      raise registration.errors.full_messages.to_sentence unless registration.save(company: company.reload, by: hr_user, starter: hr)

      registration.admission
    end
  end

  def aso_item
    in_company { instance.items.find_by!(kind: "document") }
  end

  # The ASO sent and clean, waiting for the review.
  def send_aso
    in_company do
      form = Documents::Upload.new(worker_profile: admission.worker_profile, document_type: Admissions::Aso.type, files: [ pdf ],
        by: hr_user, process_item: aso_item)
      raise form.errors.full_messages.to_sentence unless form.save

      form.version.files.blobs.each { |blob| blob.file_scan.record!(Antivirus::Clamd::Result.new(signature: nil)) }
      perform_enqueued_jobs(only: Documents::ConsolidatePdfJob)
      form.version.reload
    end
  end

  def review_aso(version, result, exam_on: Date.current)
    in_company { Documents::Review.new(version, by: hr_user).approve(issued_on: exam_on, aso_result: result) }
  end

  def resolve_tasks
    in_company do
      instance.items.reload.where(kind: %w[task approval]).find_each do |item|
        actions = Processes::ItemActions.new(item, by: hr_user)
        item.task? ? actions.complete : actions.approve
      end
    end
  end

  def fill_salary
    in_company { employment.revisions.sole.update!(salary_cents: 250_000) }
  end

  def ready
    resolve_tasks
    fill_salary
    review_aso(send_aso, "fit")
  end

  describe "the ASO (RN-07-060, RN-07-061, D-651)" do
    it "enters every CLT process, for the HR, required, never skipped nor removed (P-07-11)" do
      item = aso_item

      expect(item).to have_attributes(title: "ASO admissional", required: true, responsible_role: "hr", stage: "documents")
      in_company do
        actions = Processes::ItemActions.new(item, by: hr_user)
        expect(actions.skip(reason: "Dispensa")).to be(false)
        expect(item.errors.full_messages.to_sentence).to include("não pode ser dispensado")
      end
      sign_in_member(hr)
      delete "/processes/#{instance.id}/items/#{item.id}"
      expect(in_company { ProcessItem.exists?(item.id) }).to be(true)

      patch "/processes/#{instance.id}/items/#{item.id}", params: { item: { title: "ASO", required: "0" } }
      expect(in_company { item.reload.required }).to be(true)
    end

    it "stays out of who isn't CLT" do
      other = admit(kind: "contractor", cpf: "39053344705")

      expect(in_company { other.process_instance.items.where(kind: "document") }).to be_empty
    end

    it "asks for the result and the exam's date on the review, and resolves the item when fit (D-648)" do
      version = send_aso

      in_company { expect(Documents::Review.new(version, by: hr_user).approve).to be(false) }
      review_aso(version.reload, "fit")

      in_company do
        expect(admission.reload.aso_fit?).to be(true)
        expect(admission.aso_exam_on).to eq(Date.current)
        expect(aso_item.status).to eq("approved")
      end
    end

    it "keeps the result encrypted, out of the versions and of the history (D-086, D-651)" do
      review_aso(send_aso, "unfit")

      raw = ActiveRecord::Base.connection.select_value(ActiveRecord::Base.sanitize_sql([ "SELECT aso_status FROM admissions WHERE id = ?", admission.id ]))
      expect(raw).not_to include("unfit")
      expect(PaperTrail::Version.where(item_type: "Admission", item_id: admission.id).map { |version| "#{version.object}#{version.object_changes}" }.join).not_to include("unfit")
      expect(in_company { instance.events.map { |event| event.details.to_s }.join }).not_to include("unfit", "inapto")
    end

    it "keeps the unfit one valid in the folder, with the item open, and warns without the result (RN-07-061, RN-15-005)" do
      review_aso(send_aso, "unfit")

      in_company do
        expect(admission.reload.aso_unfit?).to be(true)
        expect(aso_item).to be_open
        expect(Document.find_by!(document_type: Admissions::Aso.type).current_version).to be_present
      end
      notice = Notification.find_by!(recipient_user: hr_user, notification_type: "admission.aso_unfit")
      expect(notice).to have_attributes(mandatory: true, urgent: true)
      expect("#{notice.title} #{notice.body}".downcase).not_to include("inapto", "aso")

      sign_in_member(hr)
      get "/admissions/#{admission.id}"
      expect(response.body).to include("precisa de uma decisão do RH", "Reavaliar", "Ver o resultado")
      # "ASO inapto" is only an option of the cancellation's fixed list; the result is "Inapto".
      expect(response.body).not_to match(/\bInapto\b/)
      expect(AccessEvent.where(kind: "sensitive_read", field: "aso_status")).to be_empty

      get "/admissions/#{admission.id}", params: { reveal: "health" }
      expect(response).to redirect_to(%r{/confirm-password})
      post "/confirm-password", params: { password: "Catalyst#2026", return_to: "/admissions" }
      get "/admissions/#{admission.id}", params: { reveal: "health" }

      expect(response.body).to include("Inapto")
      expect(AccessEvent.find_by!(kind: "sensitive_read", field: "aso_status").user_id).to eq(hr_user.id)
    end

    it "reassesses: a new version, the unfit one in the history (RN-07-061)" do
      review_aso(send_aso, "unfit")
      sign_in_member(hr)

      patch "/admissions/#{admission.id}/reassess-aso"

      expect(flash[:notice]).to include("novo exame")
      in_company do
        expect(admission.reload.aso_status).to eq("missing")
        expect(aso_item.status).to eq("pending")
        document = Document.find_by!(document_type: Admissions::Aso.type)
        form = Documents::Upload.new(document: document, worker_profile: admission.worker_profile, files: [ pdf ], by: hr_user)
        form.save
        form.version.files.blobs.each { |blob| blob.file_scan.record!(Antivirus::Clamd::Result.new(signature: nil)) }
        perform_enqueued_jobs(only: Documents::ConsolidatePdfJob)
        Documents::Review.new(form.version.reload, by: hr_user).approve(issued_on: Date.current, aso_result: "fit")
        expect(document.versions.count).to eq(2)
        expect(aso_item.status).to eq("approved")
      end
    end

    it "warns about an exam after the start, without blocking (D-651)" do
      in_company { admission }
      review_aso(send_aso, "fit", exam_on: Date.current)
      in_company { admission.update!(aso_exam_on: start + 1) }
      sign_in_member(hr)

      get "/admissions/#{admission.id}"

      expect(response.body).to include("depois do início do vínculo")
    end
  end

  describe "the conclusion (RN-07-080)" do
    it "disables the button and says why (CA-07-006)" do
      sign_in_member(hr)

      get "/admissions/#{admission.id}"

      expect(response.body).to include("Falta para concluir", "ASO admissional apto validado", "Preencher o salário", "disabled>Concluir admissão")
      patch "/admissions/#{admission.id}/complete"
      expect(flash[:alert]).to include("pendências")
      in_company { expect(admission.reload).to be_open }
    end

    it "asks for the salary, unless it's only variable (D-648)" do
      resolve_tasks
      review_aso(send_aso, "fit")

      expect(in_company { Admissions::Conclusion.new(admission.reload, by: hr_user, starter: hr).blockers }).to eq(%i[salary])

      in_company { employment.revisions.sole.update!(salary_unit: "variable_only", variable_salary_description: "Comissão") }
      expect(in_company { Admissions::Conclusion.new(Admission.find(admission.id), by: hr_user, starter: hr).blockers }).to be_empty
    end

    it "doesn't ask for the eSocial with its flag off, and says so; with it on, asks (RN-07-080, D-648)" do
      ready

      sign_in_member(hr)
      get "/admissions/#{admission.id}"
      expect(response.body).to include("Envio feito fora do sistema nesta fase")

      Flipper.enable(FeatureFlags::ESOCIAL)
      expect(in_company { Admissions::Conclusion.new(Admission.find(admission.id), by: hr_user, starter: hr).blockers }).to eq(%i[esocial])
    end

    it "ends, deletes the generated PDFs and starts the onboarding, shown in the portal (CA-07-012, RN-07-082, D-650)" do
      contract = in_company { DocumentTemplate.create!(name: "Contrato", employment_kinds: %w[clt], body: "Texto") }
      ready
      generated = in_company do
        Documents::GenerateFromTemplate.new(employment, contract).request(by: hr_user).tap { perform_enqueued_jobs(only: Documents::GenerateFromTemplateJob) }
      end
      sign_in_member(hr)

      patch "/admissions/#{admission.id}/complete"

      expect(flash[:notice]).to eq("Admissão concluída.")
      in_company do
        admission.reload
        expect(admission).to be_completed
        expect(admission).to have_attributes(completed_by_id: hr_user.id)
        expect(generated.reload.file).not_to be_attached
        started = ProcessInstance.find_by!(subject: employment, kind: "onboarding")
        expect(started).to have_attributes(status: "open", completion_mode: "automatic")
        expect(started.anchor_date("work_start")).to eq(start)
      end

      delete "/sign-out"
      person = in_company { admission.worker_profile.membership }
      person.update!(status: "active")
      person.user.update!(password: "Catalyst#2026")
      sign_in_member(person)
      get "/portal"
      expect(response.body).to include("Integração", "Boas-vindas")
    end

    it "ends the onboarding by itself when its required items end (RN-07-112)" do
      ready
      in_company { Admissions::Conclusion.new(admission.reload, by: hr_user, starter: hr).call }

      in_company do
        started = ProcessInstance.find_by!(subject: employment, kind: "onboarding")
        Processes::ItemActions.new(started.items.sole, by: hr_user).complete
        perform_enqueued_jobs(only: Processes::UnblockItemsJob)
        expect(started.reload).to be_completed
      end
    end

    it "concludes a model without onboarding, and one archived, without starting any" do
      in_company { onboarding.archive! }
      ready

      in_company do
        expect(Admissions::Conclusion.new(admission.reload, by: hr_user, starter: hr).call).to be(true)
        expect(ProcessInstance.where(subject: employment, kind: "onboarding")).to be_empty
      end
    end
  end

  describe "a refused approval (RN-07-083, D-648)" do
    let(:approval) { in_company { instance.items.find_by!(kind: "approval") } }

    before do
      in_company { Processes::ItemActions.new(approval, by: hr_user).reject(reason: "Sem vaga") }
      sign_in_member(hr)
    end

    it "shows the alert with the reason and blocks the end" do
      get "/admissions/#{admission.id}"

      expect(response.body).to include("foi reprovado: Sem vaga", "Resolver a aprovação reprovada")
    end

    it "goes back to who answers for it" do
      patch "/processes/#{instance.id}/items/#{approval.id}/reopen"

      expect(in_company { approval.reload }).to have_attributes(status: "pending", result: {})
      expect(in_company { instance.events.pluck(:action) }).to include("item_reopened")
    end

    it "may be skipped with a reason" do
      patch "/processes/#{instance.id}/items/#{approval.id}/skip", params: { skipped_reason: "Decidido pela diretoria" }

      expect(in_company { approval.reload.status }).to eq("skipped")
    end

    it "shows the actions on the process's page" do
      get "/processes/#{instance.id}"

      expect(response.body).to include("Reabrir para nova decisão")
    end
  end

  describe "the cancellation (RN-07-090 to RN-07-092)" do
    before { sign_in_member(hr) }

    def cancel(reason: "withdrew", note: nil)
      patch "/admissions/#{admission.id}/cancel", params: { cancel_reason: reason, cancel_note: note }
    end

    it "ends the employment and the process and revokes the access, keeping the data (CA-07-007)" do
      membership = in_company { admission.worker_profile.membership }

      cancel(reason: "aso_unfit")

      expect(flash[:notice]).to eq("Admissão cancelada.")
      in_company do
        admission.reload
        expect(admission.employment).to be_cancelled
        expect(admission).to be_cancelled
        expect(admission).to have_attributes(cancel_reason: "aso_unfit")
        expect(instance.reload).to have_attributes(status: "cancelled", cancel_reason: "Admissão cancelada")
        expect(WorkerProfile.exists?(admission.employment.worker_profile_id)).to be(true)
      end
      expect(membership.reload.status).to eq("revoked")
      expect(AccessEvent.find_by!(action: "admission_cancelled").subject_id).to eq(admission.id)
      raw = ActiveRecord::Base.connection.select_value(ActiveRecord::Base.sanitize_sql([ "SELECT cancel_reason FROM admissions WHERE id = ?", admission.id ]))
      expect(raw).not_to include("aso_unfit")
      get "/admissions/#{admission.id}"
      expect(response.body).to include("Ver o motivo")
      expect(response.body).not_to include("ASO inapto")
      expect(in_company { instance.events.map { |event| event.details.to_s }.join }).not_to include("inapto")
    end

    it "keeps the access of who has another employment (RN-07-091)" do
      person = register_employee(company, by: hr_user, position: position, cpf: "11144477735", started_on: Date.current - 30)
      membership = in_company { person.membership }
      membership.update!(status: "active")

      cancel

      expect(membership.reload.status).to eq("active")
    end

    it "keeps the access of who has another role, without the employee's (RN-07-091)" do
      user = create(:user, cpf: "11144477735", name: "Rafael Campos")
      membership = create(:membership, user: user, organization: company, roles: %w[manager])

      cancel

      expect(membership.reload).to have_attributes(status: "active", roles: %w[manager])
    end

    it "asks for the note on the other reason, and for a reason" do
      cancel(reason: "other")
      expect(flash[:alert]).to include("observação")

      cancel(reason: "")
      expect(flash[:alert]).to include("Escolha o motivo")
      in_company { expect(admission.reload).to be_open }
    end

    it "refuses after the activation: the way out is the termination (RN-07-092)" do
      in_company { employment.update!(status: "active") }

      cancel

      expect(flash[:alert]).to include("desligamento")
      in_company { expect(admission.reload).to be_open }
    end

    it "still cancels a concluded admission before the start, with its onboarding (D-651)" do
      ready
      in_company { Admissions::Conclusion.new(admission.reload, by: hr_user, starter: hr).call }

      cancel

      in_company do
        expect(Admission.find(admission.id)).to be_cancelled
        expect(ProcessInstance.find_by!(subject: employment, kind: "onboarding")).to be_cancelled
      end
    end
  end

  describe "documents without the documents module (spec 03, section 4.4, D-650)" do
    let(:analyst_user) { create(:user, cpf: "39053344705", name: "Ana Analista") }
    let!(:analyst) do
      create(:membership, user: analyst_user, organization: company, roles: %w[hr_analyst], enabled_modules: %w[admissao]).tap do |membership|
        in_company { MembershipUnit.create!(membership: membership, unit: company.headquarters) }
      end
    end

    def ability = CompanyAbility.new(analyst_user, company)

    it "reviews the documents of the open admission only" do
      version = send_aso
      document = in_company { version.document }
      other = register_employee(company, by: hr_user, position: position, started_on: Date.current - 30)
      other_document = in_company { Document.create!(worker_profile: other, document_type: Admissions::Aso.type, source: "hr") }

      in_company do
        expect(ability.can?(:review, document)).to be(true)
        expect(ability.can?(:upload, document)).to be(true)
        expect(ability.can?(:review, other_document)).to be(false)
      end
    end

    it "loses them when the admission ends" do
      version = send_aso
      document = in_company { version.document }
      in_company do
        instance.update!(status: "completed", completed_at: Time.current, completed_by: hr_user)
        expect(ability.can?(:review, document)).to be(false)
      end
    end

    it "stays in their units" do
      other_unit = in_company { Unit.create!(name: "Filial") }
      elsewhere = in_company { Department.create!(name: "Filial", unit: other_unit) }
      other = admit(cpf: "16899535009", unit_id: other_unit.id, department_id: elsewhere.id)

      in_company do
        document = Document.create!(worker_profile: other.worker_profile, document_type: Admissions::Aso.type, source: "hr")
        expect(ability.can?(:review, document)).to be(false)
      end
    end
  end
end
