require "rails_helper"

# Spec 04, block 4a (RN-04-002 to RN-04-014, D-600, D-601) and spec 03, section 4.2:
# the company's settings and units, and the HR analyst's units (U scope, D-142).
RSpec.describe "Company settings and units", type: :request do
  let(:company) { create(:company, name: "Metalúrgica Serra Azul", document: "11222333") }
  let(:brand) { create(:brand, owner: company, commercial_name: "Serra Azul RH") }
  let!(:hr_admin) { enable_mfa(create(:user, name: "Carlos Mendes", cpf: "98765432100")) }

  before do
    create(:membership, user: hr_admin, organization: company, roles: %w[hr_admin])
    brand.subdomains.create!(slug: "serraazul")
    Flipper.enable(FeatureFlags::SIGN_IN)
    publish_platform_legal_documents
    accept_legal_documents(hr_admin, brand)
    host! "serraazul.painel.catalysthr.com.br"
  end

  def sign_in_as(user, cpf)
    accept_legal_documents(user, brand)
    sign_in_with_mfa(cpf, user)
  end

  def unit_named(name)
    ActsAsTenant.with_tenant(company) { Unit.find_by!(name: name) }
  end

  describe "for the HR administrator" do
    before { sign_in_as(hr_admin, "98765432100") }

    it "lists the units with the headquarters and shows them in the menu" do
      get "/units"

      expect(response.body).to include("Matriz", "Nova unidade", 'href="/units"', 'href="/settings/edit"')
    end

    it "registers a branch with the address and the position confirmed on the map" do
      post "/units", params: { unit: { name: "Filial Caxias", registration_type: "cnpj", registration_number: "11.222.333/0002-62",
        postal_code: "95020-000", street: "Rua Sinimbu", street_number: "100", city: "Caxias do Sul", state: "RS",
        latitude: "-29.168", longitude: "-51.179", time_zone: "America/Sao_Paulo" } }

      unit = unit_named("Filial Caxias")
      expect(response).to redirect_to("/units/#{unit.id}")
      expect(unit).to have_attributes(registration_number: "11222333000262", postal_code: "95020000", latitude: BigDecimal("-29.168"))
    end

    it "refuses a branch with another CNPJ root (CA-04-001)" do
      post "/units", params: { unit: { name: "Filial", registration_type: "cnpj", registration_number: "11.444.777/0001-61",
        time_zone: "America/Sao_Paulo" } }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("precisa ter a mesma raiz do CNPJ da empresa (11.222.333)")
    end

    it "inactivates a branch, never the headquarters (RN-04-010, RN-04-014)" do
      branch = ActsAsTenant.with_tenant(company) { Unit.create!(name: "Obra Centro") }

      patch "/units/#{branch.id}", params: { unit: { status: "inactive" } }
      expect(branch.reload).to be_inactive

      headquarters = unit_named("Matriz")
      patch "/units/#{headquarters.id}", params: { unit: { status: "inactive" } }
      expect(headquarters.reload).to be_active
    end

    it "answers 404 for another company's unit (RN-01-013)" do
      other = create(:company)
      foreign = ActsAsTenant.with_tenant(other) { Unit.create!(name: "Filial de outra") }

      get "/units/#{foreign.id}"
      expect(response).to have_http_status(:not_found)
    end

    it "changes the names and rules, never the employer's document (D-601)" do
      get "/settings/edit"
      expect(response.body).to include("11.222.333", "Pessoa jurídica")

      patch "/settings", params: { company: { legal_name: "Serra Azul Metalurgia Ltda", read_only_period_days: 180, document: "99999999" } }

      expect(company.reload).to have_attributes(legal_name: "Serra Azul Metalurgia Ltda", read_only_period_days: 180, document: "11222333")
    end

    it "fills the address by CEP and suggests the position" do
      stub_request(:get, "https://viacep.com.br/ws/95020000/json/").to_return(body: { localidade: "Caxias do Sul", uf: "RS", ibge: "4305108" }.to_json)
      stub_request(:get, %r{nominatim}).to_return(body: [ { lat: "-29.168", lon: "-51.179" } ].to_json)

      get "/address-lookup/95020000"
      expect(response.parsed_body).to include("city" => "Caxias do Sul", "ibge_city_code" => "4305108")

      get "/geocode", params: { city: "Caxias do Sul", state: "RS" }
      expect(response.parsed_body).to eq("latitude" => "-29.168", "longitude" => "-51.179")
    end

    it "gives units to an HR analyst, only to that role (D-142)" do
      branch = ActsAsTenant.with_tenant(company) { Unit.create!(name: "Filial Caxias") }

      post "/users", params: { invitation: { name: "Joana Prado", cpf: "11144477735", email: "joana@example.com",
        roles: %w[hr_analyst], enabled_modules: %w[admissao], channels: %w[email], unit_ids: [ branch.id ] } }

      membership = Membership.find_by!(user: User.find_by!(cpf: "11144477735"))
      units = ActsAsTenant.with_tenant(company) { MembershipUnit.where(membership: membership).pluck(:unit_id) }
      expect(units).to eq([ branch.id ])
      expect(AccessEvent.where(action: "units_assigned")).to exist

      patch "/users/#{membership.id}", params: { membership: { roles: %w[manager], unit_ids: [ branch.id ] } }
      expect(ActsAsTenant.with_tenant(company) { MembershipUnit.where(membership: membership) }).to be_empty
    end
  end

  describe "for the HR analyst" do
    let!(:analyst) { enable_mfa(create(:user, cpf: "11144477735")) }

    before do
      create(:membership, user: analyst, organization: company, roles: %w[hr_analyst])
      sign_in_as(analyst, "11144477735")
    end

    it "reads the units but changes nothing, and has no settings (spec 03, section 4.2)" do
      get "/units"
      expect(response.body).to include("Matriz")
      expect(response.body).not_to include("Nova unidade", 'href="/settings/edit"')

      get "/units/new"
      expect(response).to have_http_status(:forbidden)
      get "/settings/edit"
      expect(response).to have_http_status(:forbidden)
      get "/geocode", params: { city: "Caxias do Sul", state: "RS" }
      expect(response).to have_http_status(:forbidden)
    end
  end
end
