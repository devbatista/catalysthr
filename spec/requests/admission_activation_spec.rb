require "rails_helper"

# Spec 07, block 07e (RN-07-085, RN-07-086, RN-07-100 to RN-07-102, CA-07-008 without the
# eSocial, CA-07-009, CA-07-010, D-648, D-653): the employment's start and the experience.
RSpec.describe "Admission activation and experience", type: :request do
  include ActiveJob::TestHelper

  let(:partner) { create(:partner) }
  let(:partner_brand) { create(:brand, owner: partner, commercial_name: "Aurora RH") }
  let(:company) { create(:company, partner: partner, name: "Padaria Pão Quente") }
  let(:hr_user) { create(:user, name: "Juliana Ribeiro", cpf: "52998224725") }
  let!(:hr) { create(:membership, user: hr_user, organization: company, roles: %w[hr_admin]) }
  let(:manager_user) { create(:user, name: "Gabriel Gestor", cpf: "39053344705") }
  let!(:manager) { create(:membership, user: manager_user, organization: company, roles: %w[manager]) }
  let(:position) { create_position(company, name: "Padeiro") }
  let(:department) do
    in_company { Department.create!(name: "Produção", unit: company.headquarters).tap { |area| area.managers << manager } }
  end
  let!(:template) do
    in_company do
      ProcessTemplate.create!(kind: "admission", name: "Admissão padrão").tap do |model|
        model.items.create!(position: 1, kind: "task", title: "Conferir", responsible_role: "hr")
        model.update!(status: "active")
        model.make_default!
      end
    end
  end
  let(:start) { Date.current + 10 }

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

  def sign_in_as(membership)
    user = enable_mfa(membership.user)
    accept_legal_documents(user, partner_brand)
    sign_in_with_mfa(user.cpf, user)
    post "/current-company", params: { company_id: company.id }
  end

  def admit(cpf: "11144477735", **attributes)
    in_company do
      registration = AdmissionRegistration.new({ name: "Rafael Campos", cpf: cpf, email: "#{cpf}@example.com", kind: "clt",
        category: "standard", started_on: start, position_id: position.id, unit_id: company.headquarters.id,
        department_id: department.id }.merge(attributes))
      raise registration.errors.full_messages.to_sentence unless registration.save(company: company.reload, by: hr_user, starter: hr)

      registration.admission
    end
  end

  def employment_of(admission)
    in_company { Admission.find(admission.id).employment }
  end

  def run_activation = Employments::ActivateStartingJob.perform_now
  def run_alerts = Employments::ExperienceAlertsJob.perform_now

  def notices(code, user: hr_user)
    Notification.where(notification_type: code, recipient_user: user)
  end

  describe "the activation (RN-07-085)" do
    it "activates on the date, and tells nobody when the admission ended" do
      admission = admit(started_on: Date.current)
      in_company { admission.process_instance.update!(status: "completed") }
      run_activation
      expect(employment_of(admission)).to be_active
      expect(notices("admission.activated_with_pending")).to be_empty
    end

    it "waits for the date" do
      admission = admit
      run_activation
      expect(employment_of(admission)).to be_pending
    end

    it "covers a day it didn't run" do
      admission = admit(started_on: Date.current)
      travel_to(3.days.from_now) { run_activation }
      expect(employment_of(admission)).to be_active
    end

    it "activates with the admission open and raises the serious alert, once (CA-07-008)" do
      admission = admit(started_on: Date.current)
      2.times { run_activation }
      expect(employment_of(admission)).to be_active
      notice = notices("admission.activated_with_pending").sole
      expect(notice.title).to include("Rafael Campos")
      expect(notice.urgent).to be(true)
      expect(notice.path).to eq("/admissions/#{admission.id}")

      sign_in_as(hr)
      get "/"
      expect(response.body).to include("1 admissão chegou à data de início sem terminar")
      get "/admissions"
      expect(response.body).to include("1 admissão chegou à data de início sem terminar")
      get "/admissions/#{admission.id}"
      expect(response.body).to include("O vínculo já está ativo")
    end

    it "holds an unfit ASO with a neutral alert, and frees it after the reassessment (D-653)" do
      admission = admit(started_on: Date.current)
      in_company { admission.update!(aso_status: "unfit", aso_exam_on: Date.current) }
      2.times { run_activation }
      expect(employment_of(admission)).to be_pending
      notice = notices("admission.aso_unfit").sole
      expect(notice.title + notice.body.to_s).not_to match(/inapto/i)

      sign_in_as(hr)
      get "/"
      expect(response.body).to include("chegou à data de início")
      expect(response.body).not_to match(/inapto/i)
      get "/admissions/#{admission.id}"
      expect(response.body).to include("não foi ativado")

      in_company { Admissions::Aso.reassess(admission, by: hr_user) }
      run_activation
      expect(employment_of(admission)).to be_active
    end

    it "lets the HR cancel the held one" do
      admission = admit(started_on: Date.current)
      in_company { admission.update!(aso_status: "unfit") }
      run_activation
      in_company { expect(Admissions::Cancellation.call(admission, reason: "aso_unfit", note: nil, by: hr_user)).to be(true) }
    end

    it "uses the unit's date, not the server's" do
      unit = in_company { Unit.find(company.headquarters.id) }
      in_company { unit.update!(time_zone: "America/Rio_Branco") }
      admission = admit(started_on: Date.new(2026, 12, 1))
      travel_to(Time.utc(2026, 12, 1, 4, 0)) { run_activation }
      expect(employment_of(admission)).to be_pending
      travel_to(Time.utc(2026, 12, 1, 6, 0)) { run_activation }
      expect(employment_of(admission)).to be_active
    end

    it "stays out while the flag is off" do
      admission = admit(started_on: Date.current)
      Flipper.disable(FeatureFlags::ADMISSIONS)
      run_activation
      expect(employment_of(admission)).to be_pending
    end
  end

  describe "the days (RN-07-100)" do
    it "counts the first day, and the contract follows it" do
      employment = employment_of(admit(started_on: Date.new(2026, 12, 1), experience_first_days: "45"))
      expect(employment.experience_ends_on).to eq(Date.new(2027, 1, 14))
      expect(employment.detail(:experience_status)).to eq("first_period")
      expect(employment.detail(:contract_term)).to eq("fixed")
      expect(employment.detail(:contract_end_on)).to eq("2027-01-14")
    end

    it "refuses more than 90 days (CA-07-010)" do
      sign_in_as(hr)
      post "/admissions", params: { admission: { name: "Ana Lima", cpf: "11144477735", email: "ana@example.com", kind: "clt", category: "standard",
        started_on: start, position_id: position.id, unit_id: company.headquarters.id, department_id: department.id,
        experience_first_days: "60", experience_extension_days: "45" } }
      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("passa do limite de 90 dias")
    end

    it "accepts only the standard category (D-653)" do
      sign_in_as(hr)
      post "/admissions", params: { admission: { name: "Ana Lima", cpf: "11144477735", email: "ana@example.com", kind: "clt", category: "apprentice",
        started_on: start, position_id: position.id, unit_id: company.headquarters.id, department_id: department.id,
        experience_first_days: "45" } }
      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("vale só para CLT da categoria padrão")
    end

    it "follows a new start" do
      admission = admit(experience_first_days: "30")
      in_company { expect(Admissions::Reschedule.call(admission, started_on: start + 5, by: hr_user)).to be(true) }
      expect(employment_of(admission).experience_ends_on).to eq(start + 5 + 29)
    end

    it "keeps them through the employment's form, and locks them after the start" do
      admission = admit(experience_first_days: "30")
      employment = employment_of(admission)
      sign_in_as(hr)
      get "/employments/#{employment.id}/edit"
      expect(response.body).to include("Dias do primeiro período")
      patch "/employments/#{employment.id}", params: { employment: { category: "standard", details: { labor_regime: "clt" },
        experience_first_days: "40" } }
      expect(employment.reload.experience_first_days).to eq(40)

      in_company { employment.update!(status: "active", started_on: Date.current) }
      get "/employments/#{employment.id}/edit"
      expect(response.body).not_to include("Dias do primeiro período", "Tipo de contrato", "Término do contrato")
      patch "/employments/#{employment.id}", params: { employment: { category: "standard", details: { labor_regime: "clt" },
        experience_first_days: "10" } }
      expect(employment.reload.experience_first_days).to eq(40)
      expect(employment.detail(:contract_term)).to eq("fixed")
      expect(employment.detail(:labor_regime)).to eq("clt")
    end

    it "takes it once for who already works" do
      admission = admit(started_on: Date.current)
      employment = employment_of(admission)
      in_company { employment.update!(status: "active") }
      sign_in_as(hr)
      patch "/employments/#{employment.id}", params: { employment: { category: "standard", experience_first_days: "30" } }
      expect(employment.reload.experience_first_days).to eq(30)
    end

    it "takes the settings' lead time from 1 to 30 days" do
      in_company { expect(company.update(experience_alert_days: 31)).to be(false) }
      sign_in_as(hr)
      patch "/settings", params: { company: { experience_alert_days: 15 } }
      expect(company.reload.experience_alert_days).to eq(15)
    end

    it "gives the contract its variables" do
      employment = employment_of(admit(started_on: Date.new(2026, 12, 1), experience_first_days: "45", experience_extension_days: "45"))
      values = in_company { Documents::TemplateVariables.new(employment).values }
      expect(values).to include("vinculo.experiencia_dias" => "45", "vinculo.experiencia_prorrogacao" => "45",
        "vinculo.experiencia_fim" => "14/01/2027")
    end
  end

  describe "the end of the period" do
    def on_trial(first:, extension: nil, started_on: Date.current)
      admission = admit(started_on: started_on, experience_first_days: first.to_s, experience_extension_days: extension&.to_s)
      employment = employment_of(admission)
      in_company { employment.update!(status: "active") }
      employment
    end

    it "warns the HR and the manager once, 10 days before (CA-07-009)" do
      employment = on_trial(first: 45)
      travel_to(employment.experience_ends_on - 11) { run_alerts }
      expect(notices("employments.probation_ending")).to be_empty

      travel_to(employment.experience_ends_on - 10) { run_alerts }
      travel_to(employment.experience_ends_on - 9) { run_alerts }
      travel_to(employment.experience_ends_on - 8.days + 13.hours) { run_alerts }
      notice = notices("employments.probation_ending").sole
      expect(notice.title).to eq("Fim de experiência: Rafael Campos")
      expect(notice.path).to eq("/employees/#{employment.worker_profile_id}")
      expect(notices("employments.probation_ending", user: manager_user).sole.path).to eq("/portal/team")
    end

    it "shows the three options, with \"Desligar\" disabled (CA-07-009)" do
      employment = on_trial(first: 45)
      sign_in_as(hr)
      get "/employees/#{employment.worker_profile_id}"
      expect(response.body).to include("Prorrogar", "Efetivar", "Desligar")
      expect(response.body).to match(/disabled[^>]*>Desligar/)
    end

    it "shows the manager what ends, without an action (D-653)" do
      on_trial(first: 5)
      sign_in_as(manager)
      get "/portal/team"
      expect(response.body).to include("Fim de experiência", "Rafael Campos", "A decisão é do RH")
    end

    it "extends once by the days given, and refuses a second one" do
      employment = on_trial(first: 45)
      sign_in_as(hr)
      patch "/employments/#{employment.id}/extend-experience", params: { days: 50 }
      expect(flash[:alert]).to be_present
      expect(employment.reload.detail(:experience_status)).to eq("first_period")

      patch "/employments/#{employment.id}/extend-experience", params: { days: 45 }
      expect(flash[:notice]).to be_present
      employment.reload
      expect(employment.detail(:experience_status)).to eq("extended")
      expect(employment.experience_ends_on).to eq(Date.current + 89)
      expect(employment.detail(:contract_end_on)).to eq((Date.current + 89).iso8601)
      expect(AccessEvent.where(action: "experience_extended", user: hr_user).count).to eq(1)

      patch "/employments/#{employment.id}/extend-experience", params: { days: 1 }
      expect(flash[:alert]).to be_present
    end

    it "extends by the days already informed" do
      employment = on_trial(first: 30, extension: 30)
      sign_in_as(hr)
      patch "/employments/#{employment.id}/extend-experience"
      expect(employment.reload.experience_ends_on).to eq(Date.current + 59)
    end

    it "confirms, and the contract loses the end date" do
      employment = on_trial(first: 45)
      sign_in_as(hr)
      patch "/employments/#{employment.id}/confirm-experience"
      employment.reload
      expect(employment.detail(:experience_status)).to eq("indefinite")
      expect(employment.detail(:contract_term)).to eq("indefinite")
      expect(employment.detail(:contract_end_on)).to be_nil
      expect(employment.detail(:experience_resolved_by)).to eq("Juliana Ribeiro")

      get "/employees/#{employment.worker_profile_id}"
      expect(response.body).to include("Prazo indeterminado")
      expect(response.body).not_to include("Efetivar")
      patch "/employments/#{employment.id}/confirm-experience"
      expect(flash[:alert]).to be_present
    end

    it "leaves the decision to the HR" do
      employment = on_trial(first: 45)
      sign_in_as(manager)
      patch "/employments/#{employment.id}/confirm-experience"
      expect(response).to have_http_status(:forbidden)
      expect(employment.reload.detail(:experience_status)).to eq("first_period")
    end

    it "turns indefinite on the day after, with nothing recorded, and tells the HR (RN-07-102)" do
      employment = on_trial(first: 45)
      ends_on = employment.experience_ends_on
      travel_to(ends_on) { run_alerts }
      expect(employment.reload.detail(:experience_status)).to eq("first_period")

      travel_to(ends_on + 1) { 2.times { run_alerts } }
      employment.reload
      expect(employment.detail(:experience_status)).to eq("indefinite")
      expect(employment.detail(:contract_term)).to eq("indefinite")
      expect(employment.detail(:experience_resolved_by)).to be_nil
      expect(notices("employments.probation_ending").where("title LIKE ?", "Prazo indeterminado%").count).to eq(1)
      expect(notices("employments.probation_ending", user: manager_user).where("title LIKE ?", "Prazo indeterminado%")).to be_empty
    end

    it "passes to the informed extension by itself, and then warns again (D-648)" do
      employment = on_trial(first: 30, extension: 15)
      first_end = employment.experience_ends_on
      travel_to(first_end - 10) { run_alerts }
      travel_to(first_end + 1) { run_alerts }
      employment.reload
      expect(employment.detail(:experience_status)).to eq("extended")
      expect(employment.experience_ends_on).to eq(first_end + 15)
      expect(notices("employments.probation_ending").where("title LIKE ?", "Experiência prorrogada%").count).to eq(1)
      expect(notices("employments.probation_ending").where("title LIKE ?", "Fim de experiência%").count).to eq(1)

      travel_to(first_end + 5) { run_alerts }
      expect(notices("employments.probation_ending").where("title LIKE ?", "Fim de experiência%").count).to eq(2)

      travel_to(first_end + 16) { run_alerts }
      expect(employment.reload.detail(:experience_status)).to eq("indefinite")
    end

    it "refuses a decision after the period ended" do
      employment = on_trial(first: 5)
      sign_in_as(hr)
      travel_to(Date.current + 10) do
        patch "/employments/#{employment.id}/extend-experience", params: { days: 5 }
        expect(employment.reload.detail(:experience_status)).to eq("first_period")
      end
    end
  end
end
