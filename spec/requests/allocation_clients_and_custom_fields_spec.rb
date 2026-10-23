require "rails_helper"

# Spec 04, block 4d (RN-04-080, RN-04-081, RN-04-090 to RN-04-096; CA-04-011 to
# CA-04-013), spec 02, RN-02-064, and spec 03, section 4.12 (D-570, D-605).
RSpec.describe "Allocation clients and custom fields", type: :request do
  include ActiveJob::TestHelper

  let(:company) { create(:company, name: "Consultoria Serra Azul") }
  let(:brand) { create(:brand, owner: company, commercial_name: "Serra Azul RH") }
  let!(:hr_admin) { enable_mfa(create(:user, name: "Juliana Ribeiro", cpf: "98765432100")) }
  let(:position) { create_position(company) }

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

  describe "for the HR administrator" do
    before { sign_in_as(hr_admin, "98765432100") }

    it "hides everything about clients while they are off (CA-04-011, RN-04-090)" do
      profile = register_employee(company, by: hr_admin, position: position)
      employment = in_company { profile.employments.sole }

      get "/employments/#{employment.id}/revisions/new"
      post "/confirm-password", params: { password: "Catalyst#2026", return_to: "/employments/#{employment.id}/revisions/new" }
      get "/employments/#{employment.id}/revisions/new"
      expect(response.body).not_to include("Cliente de alocação")
      expect(response.body).not_to include('href="/clients"')
      get "/clients"
      expect(response).to have_http_status(:not_found)

      patch "/settings", params: { company: { uses_allocation_clients: "1" } }
      get "/employments/#{employment.id}/revisions/new"
      expect(response.body).to include("Cliente de alocação", 'href="/clients"')
    end

    it "registers a client, invites its manager and allocates a person (RN-04-091 to RN-04-094, RN-02-064)" do
      company.update!(uses_allocation_clients: true)

      post "/clients", params: { allocation_client: { name: "Hospital Bom Pastor", document_type: "cnpj", document: "11.222.333/0001-81" } }
      client = in_company { AllocationClient.sole }
      expect(response).to redirect_to("/clients/#{client.id}")

      post "/clients/#{client.id}/invite-manager", params: { invitation: { name: "Rita Gomes", cpf: "529.982.247-25",
        email: "rita@bompastor.example", channels: [ "", "link" ] } }
      expect(response.body).to include("/invitation?token=")
      membership = Membership.find_by!(user: User.find_by!(cpf: "52998224725"), organization: company)
      expect(membership).to have_attributes(roles: %w[client_manager], status: "invited")
      expect(in_company { client.managers.to_a }).to eq([ membership ])

      get "/users"
      expect(response.body).not_to include("Rita Gomes")

      register_employee(company, by: hr_admin, position: position, name: "Ana Lima", allocation_client_id: client.id)
      get "/employees", params: { client_id: client.id }
      expect(response.body).to include("Ana Lima", "Hospital Bom Pastor · 1")
      get "/clients/#{client.id}"
      expect(response.body).to include("1 colaborador alocado", "Ana Lima", "Rita Gomes")

      patch "/clients/#{client.id}/managers", params: { membership_ids: [ "" ] }
      expect(membership.reload).to be_revoked
    end

    it "creates a custom field and fills it in the record (RN-04-080, D-605)" do
      profile = register_employee(company, by: hr_admin, position: position)

      get "/custom-fields/new"
      expect(response.body).to include("Não use estes campos para dados sensíveis")
      post "/custom-fields", params: { custom_field_definition: { label: "Tamanho do uniforme", field_type: "select",
        options_text: "P\nM\nG", required: "1" } }
      expect(response).to redirect_to("/custom-fields")

      get "/employees/#{profile.id}"
      expect(response.body).to include("Outras informações", "Campo obrigatório sem valor: Tamanho do uniforme")

      post "/confirm-password", params: { password: "Catalyst#2026", return_to: "/" }
      patch "/employees/#{profile.id}", params: { worker_profile: { city: "Caxias do Sul" } }
      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("Tamanho do uniforme é obrigatório")

      patch "/employees/#{profile.id}", params: { worker_profile: { city: "Caxias do Sul", custom_fields: { tamanho_do_uniforme: "M" } } }
      expect(response).to redirect_to("/employees/#{profile.id}")
      expect(in_company { profile.reload.custom_fields }).to eq("tamanho_do_uniforme" => "M")
    end
  end

  describe "for the client manager (K, spec 03, section 4.12)" do
    let!(:rita) { enable_mfa(create(:user, name: "Rita Gomes", cpf: "52998224725")) }

    it "sees only the basic data of the people allocated in their clients" do
      company.update!(uses_allocation_clients: true)
      hospital, school = in_company { [ AllocationClient.create!(name: "Hospital Bom Pastor"), AllocationClient.create!(name: "Escola X") ] }
      membership = create(:membership, user: rita, organization: company, roles: %w[client_manager])
      in_company { hospital.allocation_client_managers.create!(membership: membership) }
      ana = register_employee(company, by: hr_admin, position: position, name: "Ana Lima", allocation_client_id: hospital.id)
      bruno = register_employee(company, by: hr_admin, position: position, name: "Bruno Reis", allocation_client_id: school.id)
      sign_in_as(rita, "52998224725")

      get "/employees"
      expect(response.body).to include("Ana Lima")
      expect(response.body).not_to include("Bruno Reis", "Em breve", 'href="/users"')

      get "/employees/#{ana.id}"
      expect(response.body).to include("Analista de RH", "cliente Hospital Bom Pastor")
      expect(response.body).not_to include("Dados pessoais", "Salário", "PIS/NIS")

      get "/employees/#{bruno.id}"
      expect(response).to have_http_status(:not_found)
      get "/clients"
      expect(response).to have_http_status(:forbidden)
    end

    it "loses the access when the HR inactivates their only client, and the open session is refused (CA-02-018)" do
      company.update!(uses_allocation_clients: true)
      hospital = in_company { AllocationClient.create!(name: "Hospital Bom Pastor") }
      membership = create(:membership, user: rita, organization: company, roles: %w[client_manager])
      in_company { hospital.allocation_client_managers.create!(membership: membership) }
      sign_in_as(rita, "52998224725")
      get "/employees"
      expect(response).to have_http_status(:ok)
      rita_cookies = cookies.to_hash

      reset!
      host! "serraazul.painel.catalysthr.com.br"
      sign_in_as(hr_admin, "98765432100")
      patch "/clients/#{hospital.id}", params: { allocation_client: { status: "inactive" } }
      expect(membership.reload.status).to eq("revoked")

      reset!
      host! "serraazul.painel.catalysthr.com.br"
      rita_cookies.each { |name, value| cookies[name] = value }
      get "/employees"
      expect(response).to redirect_to("/sign-in")
    end
  end
end
