require "rails_helper"

# Spec 04, block 4c-2 (RN-04-041, RN-04-043, RN-04-044, RN-04-051, RN-04-054; CA-04-006,
# CA-04-008; P-03-16, D-604): emergency contacts, dependents, bank accounts, a new
# employment and the intern's conversion.
RSpec.describe "Employee records", type: :request do
  let(:company) { create(:company, name: "Metalúrgica Serra Azul") }
  let(:brand) { create(:brand, owner: company, commercial_name: "Serra Azul RH") }
  let!(:hr_admin) { enable_mfa(create(:user, name: "Juliana Ribeiro", cpf: "98765432100")) }
  let(:position) { create_position(company) }
  let(:profile) { register_employee(company, by: hr_admin, position: position, name: "Ana Lima") }

  before do
    travel_to Time.zone.local(2026, 10, 17, 10)
    create(:membership, user: hr_admin, organization: company, roles: %w[hr_admin])
    brand.subdomains.create!(slug: "serraazul")
    Flipper.enable(FeatureFlags::SIGN_IN)
    publish_platform_legal_documents
    host! "serraazul.painel.catalysthr.com.br"
  end

  after { travel_back }

  def sign_in_as(user, cpf)
    accept_legal_documents(user, brand)
    sign_in_with_mfa(cpf, user)
  end

  def in_company(&) = ActsAsTenant.with_tenant(company, &)

  def confirm_password(return_to)
    post "/confirm-password", params: { password: "Catalyst#2026", return_to: return_to }
  end

  describe "for the HR administrator" do
    before { sign_in_as(hr_admin, "98765432100") }

    it "adds, edits and removes an emergency contact (RN-04-041)" do
      post "/employees/#{profile.id}/emergency-contacts", params: { emergency_contact: { name: "João Lima", relationship: "Marido",
        phone: "(54) 99999-1234" } }
      expect(response).to redirect_to("/employees/#{profile.id}")
      contact = in_company { profile.emergency_contacts.sole }
      expect(contact.phone).to eq("54999991234")

      patch "/employees/#{profile.id}/emergency-contacts/#{contact.id}", params: { emergency_contact: { name: "João P. Lima" } }
      get "/employees/#{profile.id}"
      expect(response.body).to include("João P. Lima", "Marido", "54999991234")

      delete "/employees/#{profile.id}/emergency-contacts/#{contact.id}"
      expect(in_company { profile.emergency_contacts.count }).to eq(0)
    end

    it "adds a dependent, shows the CPF only after the password and ends it (RN-04-043, D-604)" do
      post "/employees/#{profile.id}/dependents", params: { dependent: { name: "Lia Lima", birth_date: "2018-04-02",
        relationship_type: "child", cpf: "529.982.247-25", irrf: "1" } }
      dependent = in_company { profile.dependents.sole }

      get "/employees/#{profile.id}"
      expect(response.body).to include("Lia Lima", "Filho(a)", "IRRF")
      expect(response.body).not_to include("529.982.247-25")

      confirm_password("/employees/#{profile.id}?reveal%5B%5D=documents")
      follow_redirect!
      expect(response.body).to include("529.982.247-25")
      expect(AccessEvent.where(kind: "sensitive_read", subject: dependent).pluck(:field)).to eq([ "cpf" ])

      patch "/employees/#{profile.id}/dependents/#{dependent.id}/end", params: { ended_on: "2026-10-01" }
      expect(in_company { dependent.reload }).to have_attributes(status: "ended", ended_on: Date.new(2026, 10, 1))
      get "/employees/#{profile.id}"
      expect(response.body).to include("encerrado em 01/10/2026")
    end

    it "adds accounts with the declaration, keeps one primary and the previous as history (RN-04-044, CA-04-008)" do
      params = { bank_account: { method: "account", bank_code: "001", branch: "1234", account_number: "12345-6",
        account_type: "checking", primary: "1" } }
      post "/employees/#{profile.id}/bank-accounts", params: params
      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("Confirme a declaração")

      post "/employees/#{profile.id}/bank-accounts", params: params.merge(declaration: "1")
      expect(response).to redirect_to("/employees/#{profile.id}")
      post "/employees/#{profile.id}/bank-accounts", params: { declaration: "1", bank_account: { method: "pix",
        pix_key_type: "email", pix_key: "ana@example.com", primary: "1" } }

      get "/employees/#{profile.id}"
      expect(response.body).to include("Banco 001 · agência 1234", "Titularidade declarada por Juliana Ribeiro")
      expect(response.body).not_to include("123456", "ana@example.com")

      confirm_password("/employees/#{profile.id}?reveal%5B%5D=pay")
      follow_redirect!
      expect(response.body).to include("123456", "ana@example.com")
      in_company do
        expect(profile.bank_accounts.active.sole).to have_attributes(pix_key: "ana@example.com", primary: true)
        expect(profile.bank_accounts.ended.sole.account_number).to eq("123456")
      end
    end

    it "converts an intern to CLT, keeping both in the history (CA-04-006, D-604)" do
      intern = register_employee(company, by: hr_admin, position: position, name: "Bruno Reis", kind: "intern",
        started_on: Date.new(2026, 2, 1), salary: "1.200,00")
      internship = in_company { intern.employments.sole }

      get "/employments/#{internship.id}/conversion"
      expect(response.body).to include("Efetivar como CLT", "O estágio termina no dia anterior")

      post "/employments/#{internship.id}/conversion", params: { employment_form: { category: "standard", registration_number: "50",
        started_on: "2026-10-01", position_id: position.id, unit_id: company.headquarters.id, salary: "2.400,00", salary_unit: "month" } }
      expect(response).to redirect_to("/employees/#{intern.id}")
      follow_redirect!
      expect(response.body).to include("Estagiário efetivado.", "Estágio · matrícula", "CLT · Empregado · matrícula 50", "Efetivação",
        "fim em 30/09/2026")
    end

    it "adds a second employment to someone already registered (RN-04-051)" do
      post "/employees/#{profile.id}/employments", params: { employment_form: { kind: "contractor", registration_number: "PJ-1",
        started_on: "2026-09-01", position_id: position.id, unit_id: company.headquarters.id, salary: "5.000,00", salary_unit: "month" } }

      expect(response).to redirect_to("/employees/#{profile.id}")
      expect(in_company { profile.employments.open.count }).to eq(2)
    end
  end

  describe "for the HR analyst without the payroll module (P-03-16)" do
    let!(:analyst) do
      enable_mfa(create(:user, name: "Paula Reis", cpf: "11144477735")).tap do |user|
        membership = create(:membership, user: user, organization: company, roles: %w[hr_analyst], status: "active")
        Memberships::AssignUnits.call(membership: membership, unit_ids: [ company.headquarters.id ], by: hr_admin)
      end
    end

    it "edits dependents and contacts, but sees no bank data and adds no employment" do
      target = profile
      sign_in_as(analyst, "11144477735")

      post "/employees/#{target.id}/dependents", params: { dependent: { name: "Lia Lima", birth_date: "2018-04-02", relationship_type: "child" } }
      expect(response).to redirect_to("/employees/#{target.id}")

      get "/employees/#{target.id}"
      expect(response.body).not_to include("Contas para pagamento")
      get "/employees/#{target.id}/bank-accounts/new"
      expect(response).to have_http_status(:forbidden)
      get "/employees/#{target.id}/employments/new"
      expect(response).to have_http_status(:forbidden)
    end
  end
end
