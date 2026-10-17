require "rails_helper"

# Spec 04, block 4b (RN-04-020 to RN-04-032, D-600, D-601) and spec 03, section 4.2:
# departments with managers, the E scope, and positions with the official CBO.
RSpec.describe "Departments and positions", type: :request do
  let(:company) { create(:company, name: "Metalúrgica Serra Azul") }
  let(:brand) { create(:brand, owner: company, commercial_name: "Serra Azul RH") }
  let!(:hr_admin) { enable_mfa(create(:user, name: "Juliana Ribeiro", cpf: "98765432100")) }
  let!(:carlos) { enable_mfa(create(:user, name: "Carlos Mendes", cpf: "11144477735")) }
  let!(:carlos_membership) { create(:membership, user: carlos, organization: company, roles: %w[manager], status: "active") }
  let(:unit) { company.headquarters }

  before do
    create(:membership, user: hr_admin, organization: company, roles: %w[hr_admin])
    brand.subdomains.create!(slug: "serraazul")
    CboOccupation.create!(code: "252405", title: "Analista de recursos humanos")
    Flipper.enable(FeatureFlags::SIGN_IN)
    publish_platform_legal_documents
    host! "serraazul.painel.catalysthr.com.br"
  end

  def sign_in_as(user, cpf)
    accept_legal_documents(user, brand)
    sign_in_with_mfa(cpf, user)
  end

  def in_company(&) = ActsAsTenant.with_tenant(company, &)

  describe "for the HR administrator" do
    before { sign_in_as(hr_admin, "98765432100") }

    it "builds the tree with managers and shows who approves (RN-04-021, RN-04-024)" do
      post "/departments", params: { department: { name: "Produção", unit_id: unit.id, manager_ids: [ "", carlos_membership.id ] } }
      production = in_company { Department.find_by!(name: "Produção") }
      expect(response).to redirect_to("/departments/#{production.id}")

      post "/departments", params: { department: { name: "Usinagem", unit_id: unit.id, parent_id: production.id, manager_ids: [ "" ] } }
      machining = in_company { Department.find_by!(name: "Usinagem") }

      get "/departments/#{machining.id}"
      expect(response.body).to include("Produção", "Vão para o gestor acima: Carlos Mendes.")

      get "/departments"
      expect(response.body).to include("Produção", "Usinagem", "Carlos Mendes", 'href="/departments"', 'href="/positions"')
    end

    it "refuses as manager someone without the manager role" do
      analyst = create(:membership, organization: company, roles: %w[hr_analyst], status: "active")

      post "/departments", params: { department: { name: "Produção", unit_id: unit.id, manager_ids: [ analyst.id ] } }

      expect(response).to have_http_status(:unprocessable_content)
      expect(in_company { Department.count }).to eq(0)
    end

    it "keeps the unit and refuses a cycle (RN-04-020)" do
      production, machining = in_company do
        parent = Department.create!(unit: unit, name: "Produção")
        [ parent, Department.create!(unit: unit, name: "Usinagem", parent: parent) ]
      end
      branch = in_company { Unit.create!(name: "Filial") }

      patch "/departments/#{production.id}", params: { department: { parent_id: machining.id, unit_id: branch.id } }

      expect(response).to have_http_status(:unprocessable_content)
      expect(production.reload).to have_attributes(parent_id: nil, unit_id: unit.id)
    end

    it "registers a position with the CBO and the range in reais, kept in cents (RN-04-030 to RN-04-032)" do
      get "/cbo-search", params: { q: "recursos" }
      expect(response.parsed_body).to eq([ { "code" => "252405", "title" => "Analista de recursos humanos" } ])

      post "/positions", params: { position: { name: "Analista de RH", cbo_code: "252405", salary_min: "3.000,00", salary_max: "R$ 4.500,50" } }

      position = in_company { Position.find_by!(name: "Analista de RH") }
      expect(position).to have_attributes(salary_min_cents: 300_000, salary_max_cents: 450_050)
      follow_redirect!
      expect(response.body).to include("R$ 3.000,00 a R$ 4.500,50", "252405 · Analista de recursos humanos")
    end

    it "explains an invalid amount and a CBO out of the table" do
      post "/positions", params: { position: { name: "Inventado", cbo_code: "999999", salary_min: "três mil" } }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("precisa ser um valor em reais, como 2.500,00")

      post "/positions", params: { position: { name: "Inventado", cbo_code: "999999" } }
      expect(response.body).to include("não está na tabela oficial da CBO")
    end
  end

  describe "for the HR analyst" do
    let!(:analyst) { enable_mfa(create(:user, cpf: "39053344705")) }

    before do
      create(:membership, user: analyst, organization: company, roles: %w[hr_analyst])
      in_company { Department.create!(unit: unit, name: "Produção") }
      sign_in_as(analyst, "39053344705")
    end

    it "reads departments and positions and changes nothing (spec 03, section 4.2)" do
      get "/departments"
      expect(response.body).to include("Produção")
      expect(response.body).not_to include("Novo departamento")

      get "/positions/new"
      expect(response).to have_http_status(:forbidden)
      get "/cbo-search", params: { q: "recursos" }
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "for the manager (E scope, D-190)" do
    before { sign_in_as(carlos, "11144477735") }

    it "reads only their departments, with the subdepartments, and those units" do
      production, machining, other = in_company do
        parent = Department.create!(unit: unit, name: "Produção")
        parent.department_managers.create!(membership: carlos_membership)
        branch = Unit.create!(name: "Filial Bento")
        [ parent, Department.create!(unit: unit, name: "Usinagem", parent: parent), Department.create!(unit: branch, name: "Logística") ]
      end

      get "/departments"
      expect(response.body).to include("Produção", "Usinagem")
      expect(response.body).not_to include("Logística", "Novo departamento")

      get "/departments/#{other.id}"
      expect(response).to have_http_status(:not_found)
      get "/units"
      expect(response.body).to include("Matriz")
      expect(response.body).not_to include("Filial Bento")
      expect([ production, machining ]).to all(be_persisted)
    end
  end
end
