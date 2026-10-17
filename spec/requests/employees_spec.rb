require "rails_helper"

# Spec 04, block 4c-1 (RN-04-040 to RN-04-064, CA-04-004, CA-04-005, CA-04-010; D-600,
# D-602, D-603), spec 03, section 4.3, and the password before sensitive data (RN-02-052,
# RN-05-001, RN-05-020, D-183, D-592).
RSpec.describe "Employees", type: :request do
  let(:company) { create(:company, name: "Metalúrgica Serra Azul") }
  let(:brand) { create(:brand, owner: company, commercial_name: "Serra Azul RH") }
  let!(:hr_admin) { enable_mfa(create(:user, name: "Juliana Ribeiro", cpf: "98765432100")) }
  let(:position) { create_position(company, salary_min_cents: 200_000, salary_max_cents: 350_000) }
  let(:branch) { in_company { Unit.create!(name: "Filial Bento") } }

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

  def confirm_password(password = "Catalyst#2026")
    post "/confirm-password", params: { password: password, return_to: request.fullpath }
  end

  describe "for the HR administrator" do
    before { sign_in_as(hr_admin, "98765432100") }

    it "registers someone who already works in the company and lists them (RN-04-040, D-600)" do
      get "/employees/new"
      expect(response.body).to include('value="1"', "Novo colaborador")

      post "/employees", params: { employee: {
        name: "Ana Lima", cpf: "529.982.247-25", birth_date: "1990-05-10", email: "ana@example.com", kind: "clt",
        category: "standard", registration_number: "1", started_on: "2026-03-01", position_id: position.id,
        unit_id: company.headquarters.id, salary: "2.500,00", salary_unit: "month", weekly_hours: "44"
      } }
      profile = in_company { WorkerProfile.sole }
      expect(response).to redirect_to("/employees/#{profile.id}")
      follow_redirect!
      expect(response.body).to include("Colaborador cadastrado.", "Ana Lima", "matrícula 1", "Analista de RH", "44 horas")
      expect(response.body).not_to include("2.500,00")

      get "/employees"
      expect(response.body).to include("Ana Lima", "Matriz · 1", 'href="/employees"')
      expect(response.body).not_to include("soon/employees")
    end

    it "asks for the justification of a salary out of the range (CA-04-005)" do
      post "/employees", params: { employee: {
        name: "Ana Lima", cpf: "529.982.247-25", email: "ana@example.com", kind: "clt", category: "standard",
        registration_number: "1", started_on: "2026-03-01", position_id: position.id, unit_id: company.headquarters.id,
        salary: "1.800,00", salary_unit: "month"
      } }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("fora da faixa do cargo")
    end

    it "shows documents only after the password, and records each value shown (RN-02-052, RN-05-020)" do
      profile = register_employee(company, by: hr_admin, position: position)
      in_company { profile.update!(rg_number: "12.345.678-9", pis_nis: "12012345678") }

      get "/employees/#{profile.id}"
      expect(response.body).not_to include("123456789")
      expect(response.body).to include("••••••")

      get "/employees/#{profile.id}", params: { reveal: [ "documents" ] }
      expect(response).to redirect_to(%r{/confirm-password\?return_to=})

      post "/confirm-password", params: { password: "errada", return_to: "/employees/#{profile.id}?reveal%5B%5D=documents" }
      expect(response).to have_http_status(:unprocessable_content)
      expect(AccessEvent.where(kind: "auth", action: "sensitive_confirmation_failed", user: hr_admin).count).to eq(1)

      post "/confirm-password", params: { password: "Catalyst#2026", return_to: "/employees/#{profile.id}?reveal%5B%5D=documents" }
      expect(response).to redirect_to("/employees/#{profile.id}?reveal%5B%5D=documents")
      follow_redirect!
      expect(response.body).to include("123456789", "12012345678")
      reads = AccessEvent.where(kind: "sensitive_read", user: hr_admin, subject: profile)
      expect(reads.pluck(:field)).to contain_exactly("rg_number", "pis_nis")

      travel 6.minutes
      get "/employees/#{profile.id}", params: { reveal: [ "documents" ] }
      expect(response).to redirect_to(%r{/confirm-password\?return_to=})
    end

    it "never goes back to another host after the password" do
      post "/confirm-password", params: { password: "Catalyst#2026", return_to: "//evil.example.com/x" }

      expect(response).to redirect_to("/")
    end

    it "schedules a raise and keeps the revision in force unchanged (CA-04-004, D-603)" do
      profile = register_employee(company, by: hr_admin, position: position, salary: "2.000,00")
      employment = in_company { profile.employments.sole }

      get "/employments/#{employment.id}/revisions/new"
      expect(response).to redirect_to(%r{/confirm-password\?return_to=})
      confirm_password
      get "/employments/#{employment.id}/revisions/new"
      expect(response.body).to include('value="R$ 2.000,00"')

      post "/employments/#{employment.id}/revisions", params: { employment_revision: {
        effective_on: "2026-12-01", reason: "salary_change", position_id: position.id, unit_id: company.headquarters.id,
        salary: "2.300,00", salary_unit: "month"
      } }
      expect(response).to redirect_to("/employees/#{profile.id}")
      follow_redirect!
      expect(response.body).to include("Revisão registrada.", "Revisão agendada a partir de 01/12/2026")

      get "/employees/#{profile.id}", params: { reveal: [ "pay" ] }
      expect(response.body).to include("R$ 2.000,00 por mês", "R$ 2.300,00 por mês")

      admission = in_company { employment.revisions.first }
      get "/employments/#{employment.id}/revisions/#{admission.id}/edit"
      expect(response).to redirect_to("/employees/#{profile.id}")
      expect(flash[:alert]).to include("já está em vigor")
    end

    it "warns about a retroactive revision (RN-04-062)" do
      profile = register_employee(company, by: hr_admin, position: position)
      employment = in_company { profile.employments.sole }
      get "/employments/#{employment.id}/revisions/new"
      confirm_password

      post "/employments/#{employment.id}/revisions", params: { employment_revision: {
        effective_on: "2026-09-01", reason: "promotion", position_id: position.id, unit_id: company.headquarters.id,
        salary: "2.600,00", salary_unit: "month"
      } }
      expect(flash[:notice]).to include("retroativa", "retificar o eSocial")
    end

    it "edits the record after the password, with the documents" do
      profile = register_employee(company, by: hr_admin, position: position)

      get "/employees/#{profile.id}/edit"
      expect(response).to redirect_to(%r{/confirm-password\?return_to=})
      confirm_password
      patch "/employees/#{profile.id}", params: { worker_profile: { city: "Caxias do Sul", state: "RS", rg_number: "998877",
        disability_types: [ "", "visual" ] } }

      expect(response).to redirect_to("/employees/#{profile.id}")
      expect(in_company { profile.reload }).to have_attributes(city: "Caxias do Sul", rg_number: "998877", disability_types: %w[visual])
    end

    it "edits the details of the employment's kind (RN-04-053)" do
      profile = register_employee(company, by: hr_admin, position: position)
      employment = in_company { profile.employments.sole }

      patch "/employments/#{employment.id}", params: { employment: { category: "apprentice",
        details: { contract_term: "fixed", contract_end_on: "2027-02-28", union_cnpj: "11.222.333/0001-81" } } }

      expect(response).to redirect_to("/employees/#{profile.id}")
      expect(in_company { employment.reload }).to have_attributes(category: "apprentice",
        details: { "contract_term" => "fixed", "contract_end_on" => "2027-02-28", "union_cnpj" => "11222333000181" })
    end

    it "keeps employees out of the users screen and their access while employed (RN-04-055)" do
      register_employee(company, by: hr_admin, position: position, name: "Ana Lima")
      manager = create(:membership, organization: company, roles: %w[manager], status: "active",
        user: create(:user, name: "Carlos Mendes"))
      register_employee(company, by: hr_admin, position: position, cpf: manager.user.cpf)

      get "/users"
      expect(response.body).to include("Carlos Mendes")
      expect(response.body).not_to include("Ana Lima")

      delete "/users/#{manager.id}"
      expect(flash[:alert]).to include("vínculo ativo")
      expect(manager.reload).to be_active
    end
  end

  describe "for the HR analyst (U, P-03-16)" do
    let!(:analyst) do
      enable_mfa(create(:user, name: "Paula Reis", cpf: "11144477735")).tap do |user|
        membership = create(:membership, user: user, organization: company, roles: %w[hr_analyst], status: "active")
        Memberships::AssignUnits.call(membership: membership, unit_ids: [ branch.id ], by: hr_admin)
      end
    end

    it "sees the people of their units, without pay unless the payroll module is released" do
      mine = register_employee(company, by: hr_admin, position: position, name: "Bruno Reis", unit: branch)
      other = register_employee(company, by: hr_admin, position: position, name: "Ana Lima")
      sign_in_as(analyst, "11144477735")

      get "/employees"
      expect(response.body).to include("Bruno Reis")
      expect(response.body).not_to include("Ana Lima")

      get "/employees/#{other.id}"
      expect(response).to have_http_status(:not_found)

      get "/employees/#{mine.id}"
      expect(response.body).to include("PIS/NIS")
      expect(response.body).not_to include("Salário")
      get "/employments/#{in_company { mine.employments.sole.id }}/revisions/new"
      expect(response).to have_http_status(:forbidden)
      get "/employees/new"
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "for the manager (E)" do
    let!(:carlos) { enable_mfa(create(:user, name: "Carlos Mendes", cpf: "11144477735")) }
    let!(:carlos_membership) { create(:membership, user: carlos, organization: company, roles: %w[manager], status: "active") }

    it "sees the team's basic data only" do
      production = in_company { Department.create!(unit: company.headquarters, name: "Produção") }
      in_company { production.department_managers.create!(membership: carlos_membership) }
      team = register_employee(company, by: hr_admin, position: position, name: "Bruno Reis", department: production)
      other = register_employee(company, by: hr_admin, position: position, name: "Ana Lima")
      sign_in_as(carlos, "11144477735")

      get "/employees"
      expect(response.body).to include("Bruno Reis", "Carlos Mendes")
      expect(response.body).not_to include("Ana Lima")

      get "/employees/#{team.id}"
      expect(response.body).to include("Analista de RH", "Matriz › Produção")
      expect(response.body).not_to include("Dados pessoais", "PIS/NIS", "Salário", "CPF")

      get "/employees/#{other.id}"
      expect(response).to have_http_status(:not_found)
    end
  end
end
