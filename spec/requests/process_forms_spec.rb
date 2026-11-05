require "rails_helper"

# Spec 07, block 07b (RN-06-030, RN-06-031, RN-07-031, D-649): the form item, from the
# portal to the record.
RSpec.describe "Process forms", type: :request do
  include ActiveJob::TestHelper

  let(:partner) { create(:partner) }
  let(:partner_brand) { create(:brand, owner: partner, commercial_name: "Aurora RH") }
  let(:company) { create(:company, partner: partner, name: "Padaria Pão Quente") }
  let(:hr_user) { create(:user, name: "Juliana Ribeiro", cpf: "52998224725") }
  let!(:hr) { create(:membership, user: hr_user, organization: company, roles: %w[hr_admin]) }
  let(:position) { create_position(company, name: "Padeiro") }
  let(:department) { in_company { Department.create!(name: "Produção", unit: company.headquarters) } }
  let!(:custom) { in_company { CustomFieldDefinition.create!(label: "Camiseta", field_type: "text") } }
  let!(:template) do
    in_company do
      model = ProcessTemplate.create!(kind: "admission", name: "Admissão padrão")
      model.items.create!(position: 1, kind: "form", title: "Dados pessoais", responsible_role: "employee", config: {
        "groups" => %w[identification documents disability contact dependents emergency_contacts bank_account],
        "custom_field_keys" => [ custom.key ], "free_fields" => [ "Alergias" ]
      })
      model.items.create!(position: 2, kind: "task", title: "Depois do formulário", responsible_role: "hr",
        depends_on_item_ids: [ model.items.first.id ])
      model.update!(status: "active")
      model.make_default!
      model
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
  let(:instance) { in_company { admission.process_instance } }
  let(:item) { in_company { instance.items.find_by!(kind: "form") } }
  let(:profile) { in_company { admission.worker_profile } }
  let(:employee) { profile.membership.tap { |membership| membership.update!(status: "active") } }
  let(:answers) do
    { fields: { sex: "male", rg_number: "12.345.678-9", pis_nis: "12056412547", personal_email: "pessoal@example.com", disability_types: [ "", "visual" ] },
      custom: { custom.key => "G" }, free: { "Alergias" => "Glúten" },
      rows: { dependents: { "0" => { name: "Lia Campos", relationship_type: "child", birth_date: "2020-01-15", cpf: "39053344705", irrf: "1" } },
              emergency_contacts: { "0" => { name: "Ana Campos", relationship: "Mãe", phone: "54999990000" } } },
      bank_account: { bank_code: "341", branch: "1234", account_number: "98765-4", account_type: "checking" } }
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
    user.update!(password: "Catalyst#2026") unless user.valid_password?("Catalyst#2026")
    accept_legal_documents(user, partner_brand)
    sign_in_with_mfa(user.cpf, user)
    post "/current-company", params: { company_id: company.id }
  end

  def confirm_password(return_to = "/portal")
    post "/confirm-password", params: { password: "Catalyst#2026", return_to: return_to }
  end

  def response_record
    in_company { ProcessFormResponse.find_by(process_item_id: item.id) }
  end

  def raw_answers
    ActiveRecord::Base.connection.select_value(ActiveRecord::Base.sanitize_sql([ "SELECT answers FROM process_form_responses WHERE process_item_id = ?", item.id ]))
  end

  def submit_as_employee
    in_company do
      Processes::FormItem.new(item, by: employee.user).submit(answers)
    end
  end

  describe "the employee in the portal" do
    before { sign_in_member(employee) }

    it "lists the form, saves a draft on the server, encrypted, and touches nothing in the record (RN-06-031)" do
      get "/portal"
      expect(response.body).to include("Dados pessoais")

      patch "/portal/items/#{item.id}/form", params: { form: { fields: { rg_number: "12.345.678-9", sex: "male" } } }

      expect(flash[:notice]).to include("continuar depois")
      expect(raw_answers).not_to include("12.345.678-9")
      expect(response_record.data.dig("fields", "rg_number")).to eq("12.345.678-9")
      in_company { expect(profile.reload.rg_number).to be_nil }
      expect(item.reload.status).to eq("pending")
    end

    it "never shows a sensitive answer back, and blank keeps it (D-649)" do
      patch "/portal/items/#{item.id}/form", params: { form: { fields: { rg_number: "123456789", sex: "male" } } }

      get "/portal/items/#{item.id}"
      expect(response.body).to include("Já informado")
      expect(response.body).not_to include("123456789")

      patch "/portal/items/#{item.id}/form", params: { form: { fields: { rg_number: "", sex: "female" } } }

      expect(response_record.data["fields"]).to include("rg_number" => "123456789", "sex" => "female")
    end

    it "fills the common fields from the record, never the sensitive ones (D-649)" do
      in_company { profile.update!(personal_email: "antigo@example.com", rg_number: "998877") }

      get "/portal/items/#{item.id}"

      expect(response.body).to include("antigo@example.com", "Já informado")
      expect(response.body).not_to include("998877")
    end

    it "sends it to the HR, who is told without any answer (D-649)" do
      patch "/portal/items/#{item.id}/form", params: { form: answers, send_form: "1" }

      expect(flash[:notice]).to eq("Formulário enviado ao RH.")
      expect(item.reload.status).to eq("submitted")
      notice = Notification.find_by!(recipient_user: hr_user, notification_type: "processes.form_submitted")
      expect(notice.title + notice.body.to_s).not_to include("12.345", "98765", "Lia")
    end

    it "refuses invalid data with the record's own rules, keeping the draft" do
      bad = answers.deep_merge(fields: { pis_nis: "123" })

      patch "/portal/items/#{item.id}/form", params: { form: bad, send_form: "1" }

      expect(response).to have_http_status(:unprocessable_content)
      expect(item.reload.status).to eq("pending")
      expect(response_record.data.dig("fields", "pis_nis")).to eq("123")
    end

    it "doesn't keep keys the form doesn't ask (FormSchema)" do
      patch "/portal/items/#{item.id}/form", params: { form: { fields: { sex: "male", membership_id: "x", ctps_number: "1" }, custom: { other: "x" } } }

      expect(response_record.data["fields"].keys).to include("sex", "ctps_number")
      expect(response_record.data["fields"].keys).not_to include("membership_id")
      expect(response_record.data["custom"]).to be_blank
    end

    it "doesn't open the form of someone else (RN-03-006)" do
      other = in_company { ProcessItem.create!(instance: instance, position: 9, kind: "form", title: "Alheio", status: "pending", responsible_role: "hr", responsible_membership_ids: [ hr.id ]) }

      get "/portal/items/#{other.id}"

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "the HR" do
    before do
      employee
      submit_as_employee
      sign_in_member(hr)
    end

    it "asks for the password and turns each sensitive value into an access event (RN-02-052, RN-05-020)" do
      get "/processes/#{instance.id}/items/#{item.id}/form/edit"
      expect(response).to redirect_to(%r{/confirm-password})

      confirm_password
      get "/processes/#{instance.id}/items/#{item.id}/form/edit"

      expect(response.body).to include("12.345.678-9", "Glúten", "Aplicar na ficha")
      events = AccessEvent.where(kind: "sensitive_read", user: hr_user).pluck(:field)
      expect(events).to include("rg_number", "pis_nis", "disability_types", "dependents.0.cpf", "bank_number")
    end

    it "applies everything, wipes the copy and frees what waits (RN-06-031, D-649)" do
      confirm_password
      patch "/processes/#{instance.id}/items/#{item.id}/form/apply", params: { form: answers }

      expect(flash[:notice]).to eq("Formulário aplicado na ficha.")
      in_company do
        person = WorkerProfile.find(profile.id)
        expect(person).to have_attributes(sex: "male", rg_number: "123456789", pis_nis: "12056412547", personal_email: "pessoal@example.com")
        expect(person.disability_types).to eq(%w[visual])
        expect(person.custom_fields[custom.key]).to eq("G")
        expect(person.dependents.sole).to have_attributes(name: "Lia Campos", irrf: true)
        expect(person.emergency_contacts.sole.name).to eq("Ana Campos")
        expect(person.bank_accounts.sole).to have_attributes(account_number: "987654", primary: true, declared_by_id: hr_user.id)
      end
      record = response_record
      expect(record.data).to eq("free" => { "Alergias" => "Glúten" })
      expect(record.applied_fields).to include("rg_number", "dependent", "bank_account", "custom:#{custom.key}")
      expect(record.applied_by_id).to eq(hr_user.id)
      expect(item.reload).to have_attributes(status: "done", completed_by_id: hr_user.id)
      perform_enqueued_jobs(only: Processes::UnblockItemsJob)
      expect(in_company { instance.items.find_by!(title: "Depois do formulário").status }).to eq("pending")
      expect(AccessEvent.find_by!(action: "form_applied").subject_id).to eq(item.id)
    end

    it "doesn't put answers in the versions nor in the history (D-086, RN-06-051)" do
      confirm_password
      patch "/processes/#{instance.id}/items/#{item.id}/form/apply", params: { form: answers }

      expect(PaperTrail::Version.where(item_type: "ProcessFormResponse")).to be_empty
      expect(PaperTrail::Version.where(item_id: profile.id).map { |version| version.object_changes.to_s }.join).not_to include("123456789")
      expect(in_company { instance.events.map { |event| event.details.to_s }.join }).not_to include("123456789", "98765")
    end

    it "lets the HR correct before applying (RN-06-031)" do
      confirm_password
      corrected = answers.deep_merge(fields: { rg_number: "111222333" })

      patch "/processes/#{instance.id}/items/#{item.id}/form/apply", params: { form: corrected }

      expect(in_company { WorkerProfile.find(profile.id).rg_number }).to eq("111222333")
    end

    it "never lets a blank wipe a value of the record (D-649)" do
      in_company { profile.update!(personal_phone: "54988887777") }
      confirm_password

      patch "/processes/#{instance.id}/items/#{item.id}/form/apply", params: { form: answers.deep_merge(fields: { personal_phone: "" }) }

      expect(in_company { WorkerProfile.find(profile.id).personal_phone }).to eq("54988887777")
    end

    it "stays on the page when something is invalid, applying nothing" do
      confirm_password

      patch "/processes/#{instance.id}/items/#{item.id}/form/apply", params: { form: answers.deep_merge(bank_account: { bank_code: "1" }) }

      expect(response).to have_http_status(:unprocessable_content)
      expect(item.reload.status).to eq("submitted")
      expect(in_company { WorkerProfile.find(profile.id).rg_number }).to be_nil
    end

    it "gives it back with a reason the person sees, and the person sends it again (D-649)" do
      patch "/processes/#{instance.id}/items/#{item.id}/form/give-back", params: { reason: "Confira o PIS" }

      expect(item.reload.status).to eq("correction_requested")
      expect(Notification.find_by!(recipient_user: employee.user).notification_type).to eq("processes.form_correction_requested")

      delete "/sign-out"
      sign_in_member(employee)
      get "/portal"
      expect(response.body).to include("Dados pessoais")
      get "/portal/items/#{item.id}"
      expect(response.body).to include("Confira o PIS")

      patch "/portal/items/#{item.id}/form", params: { form: answers, send_form: "1" }
      expect(item.reload.status).to eq("submitted")
      expect(response_record.correction_reason).to be_nil
    end

    it "asks for the reason" do
      patch "/processes/#{instance.id}/items/#{item.id}/form/give-back", params: { reason: "" }

      expect(flash[:alert]).to include("motivo")
      expect(item.reload.status).to eq("submitted")
    end

    it "wipes the answers when the item is skipped (D-649)" do
      in_company { Processes::ItemActions.new(item, by: hr_user).skip(reason: "Não se aplica") }

      expect(response_record.answers).to be_nil
    end

    it "wipes the answers when the process is cancelled, as in a change of model (D-649)" do
      in_company { Processes::Complete.cancel(instance, by: hr_user, reason: "Modelo trocado") }

      expect(response_record.answers).to be_nil
    end

    it "shows the way from the checklist" do
      get "/processes/#{instance.id}"

      expect(response.body).to include("Revisar e aplicar")
    end
  end

  describe "the HR filling in the person's name, before the access (RN-07-021)" do
    it "fills and applies without the employee" do
      sign_in_member(hr)
      get "/processes/#{instance.id}/items/#{item.id}/form/edit"
      confirm_password

      patch "/processes/#{instance.id}/items/#{item.id}/form", params: { form: { fields: { sex: "male" } } }
      expect(flash[:notice]).to eq("Formulário salvo.")

      patch "/processes/#{instance.id}/items/#{item.id}/form/apply", params: { form: { fields: { sex: "male" } } }

      expect(in_company { WorkerProfile.find(profile.id).sex }).to eq("male")
      expect(item.reload.status).to eq("done")
    end
  end

  describe "the HR analyst" do
    let(:analyst_user) { create(:user, cpf: "39053344705", name: "Ana Analista") }
    let!(:analyst) do
      create(:membership, user: analyst_user, organization: company, roles: %w[hr_analyst], enabled_modules: %w[admissao]).tap do |membership|
        in_company { MembershipUnit.create!(membership: membership, unit: company.headquarters) }
      end
    end

    before do
      employee
      submit_as_employee
      sign_in_member(analyst)
    end

    it "reviews and applies the bank data of an open admission without the payroll module, and doesn't see it after (P-03-16, D-649)" do
      confirm_password
      get "/processes/#{instance.id}/items/#{item.id}/form/edit"
      expect(response.body).to include("98765-4")

      patch "/processes/#{instance.id}/items/#{item.id}/form/apply", params: { form: answers }

      expect(item.reload.status).to eq("done")
      ability = in_company { CompanyAbility.new(analyst_user, company) }
      expect(ability.can?(:read_pay, in_company { WorkerProfile.find(profile.id) })).to be(false)
    end
  end

  describe "another scope" do
    it "answers 404 to an analyst of another unit" do
      other_unit = in_company { Unit.create!(name: "Filial") }
      user = create(:user, cpf: "39053344705")
      analyst = create(:membership, user: user, organization: company, roles: %w[hr_analyst], enabled_modules: %w[admissao])
      in_company { MembershipUnit.create!(membership: analyst, unit: other_unit) }
      item
      sign_in_member(analyst)

      get "/processes/#{instance.id}/items/#{item.id}/form/edit"

      expect(response).to have_http_status(:not_found)
    end
  end
end
