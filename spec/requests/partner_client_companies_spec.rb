require "rails_helper"

# P-03-14, RN-19-012, D-616: the partner's administrator registers a client company with
# the contracted modules it uses and its first HR administrator, and turns the modules
# on or off for each company of the portfolio.
RSpec.describe "Partner's client companies", type: :request do
  include ActiveJob::TestHelper

  let(:partner) { create(:partner, name: "Aurora Gestão de Pessoas") }
  let(:brand) { create(:brand, owner: partner, commercial_name: "Aurora RH") }
  let!(:padaria) { create(:company, partner: partner, name: "Padaria Pão Quente") }
  let!(:outsider) { create(:company, :with_partner, name: "Cliente de Outro Parceiro") }
  let!(:admin) { enable_mfa(create(:user, name: "Paula Admin", cpf: "98765432100")) }
  let(:cnpj) { generate(:cnpj) }
  let(:params) do
    { company: { legal_name: "Mercado Bom Preço Ltda", commercial_name: "Mercado Bom Preço", cnpj: cnpj,
                 modules: [ "", "ponto", "folha" ], admin_name: "Joana Prado", admin_cpf: "111.444.777-35",
                 admin_email: "joana@example.com" } }
  end

  before do
    create(:membership, user: admin, organization: partner, roles: %w[partner_admin])
    brand.subdomains.create!(slug: "aurora")
    Flipper.enable(FeatureFlags::SIGN_IN)
    Flipper.enable(FeatureFlags::BILLING)
    publish_platform_legal_documents
    host! "aurora.painel.catalysthr.com.br"
  end

  def sign_in_as(user, cpf)
    accept_legal_documents(user, brand)
    sign_in_with_mfa(cpf, user)
  end

  describe "with the partner under contract" do
    before do
      contract_for(partner)
      sign_in_as(admin, "98765432100")
    end

    it "registers the company in the portfolio, with the modules on, and invites its first HR administrator (P-03-14)" do
      get "/partner"
      expect(response.body).to include("Cadastrar empresa")
      get "/partner/companies/new"
      expect(response.body).to include("Cadastrar empresa cliente", "Ponto", "Folha")
      expect(response.body.scan(/type="checkbox"[^>]*checked/).size).to eq(2)

      perform_enqueued_jobs do
        post "/partner/companies", params: params
      end

      company = Company.find_by!(name: "Mercado Bom Preço")
      expect(response).to redirect_to("/partner")
      expect(flash[:notice]).to eq("Empresa Mercado Bom Preço cadastrada. O convite foi enviado para joana@example.com.")
      expect(company).to have_attributes(partner: partner, legal_name: "Mercado Bom Preço Ltda", document: Cnpj.normalize(cnpj)[0, 8])
      expect(company.headquarters.registration_number).to eq(Cnpj.normalize(cnpj))
      expect(company.module_settings.pluck(:module, :enabled, :changed_by_id)).to contain_exactly(
        [ "ponto", true, admin.id ], [ "folha", true, admin.id ])
      membership = Membership.find_by!(organization: company)
      expect(membership).to have_attributes(roles: %w[hr_admin], status: "invited")
      expect(membership.user).to have_attributes(name: "Joana Prado", cpf: "11144477735")
      expect(ActionMailer::Base.deliveries.last.to).to eq([ "joana@example.com" ])
      expect(company.contract_modules.contracted).to contain_exactly("ponto", "folha")

      follow_redirect!
      expect(response.body).to include("Mercado Bom Preço", "Ponto e Folha")
    end

    it "leaves off the modules not marked" do
      post "/partner/companies", params: params.deep_merge(company: { modules: [ "", "folha" ] })

      company = Company.find_by!(name: "Mercado Bom Preço")
      expect(company.module_settings.pluck(:module, :enabled)).to contain_exactly([ "ponto", false ], [ "folha", true ])
      expect(company.contract_modules.contracted).to eq(%w[folha])
    end

    it "keeps the data of a person who already has an account (RN-02-010)" do
      create(:user, name: "Joana Antiga", cpf: "11144477735", email: "joana.antiga@example.com")

      post "/partner/companies", params: params

      expect(flash[:notice]).to include("já tinha conta na plataforma")
      expect(User.find_by!(cpf: "11144477735")).to have_attributes(name: "Joana Antiga", email: "joana.antiga@example.com")
    end

    it "saves nothing when something is wrong" do
      create(:company, document: Cnpj.normalize(cnpj)[0, 8])

      expect {
        post "/partner/companies", params: params.deep_merge(company: { admin_email: "" })
        post "/partner/companies", params: params
      }.not_to change { [ Company.count, User.count, Membership.count, CompanyModuleSetting.count ] }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("CNPJ")
    end

    it "turns the modules on and off for a company of the portfolio, recording who did it (RN-19-012)" do
      turn_on_modules(padaria, %w[ponto])

      get "/partner"
      expect(response.body).to include("Padaria Pão Quente", "Ponto")
      get "/partner/companies/#{padaria.id}/modules/edit"
      expect(response.body).to include("Módulos de Padaria Pão Quente", "Salvar módulos")

      patch "/partner/companies/#{padaria.id}/modules", params: { company: { modules: [ "", "folha" ] } }

      expect(response).to redirect_to("/partner")
      expect(padaria.module_settings.pluck(:module, :enabled, :changed_by_id)).to contain_exactly(
        [ "ponto", false, admin.id ], [ "folha", true, admin.id ])
    end

    it "does not turn on a module out of the contract" do
      Subscription.sole.items.find_by!(module: "ponto").update!(ends_on: Date.yesterday, starts_on: Date.yesterday)

      patch "/partner/companies/#{padaria.id}/modules", params: { company: { modules: %w[ponto folha] } }

      expect(padaria.module_settings.pluck(:module, :enabled)).to eq([ [ "folha", true ] ])
    end

    it "does not find another partner's company (RN-01-013)" do
      get "/partner/companies/#{outsider.id}/modules/edit"

      expect(response).to have_http_status(:not_found)
    end
  end

  it "hides the registration and the modules while billing is off (D-610)" do
    Flipper.disable(FeatureFlags::BILLING)
    contract_for(partner)
    sign_in_as(admin, "98765432100")

    get "/partner"
    expect(response.body).to include("Padaria Pão Quente")
    expect(response.body).not_to include("Cadastrar empresa", "Módulos")
    get "/partner/companies/new"
    expect(response).to have_http_status(:not_found)
    patch "/partner/companies/#{padaria.id}/modules", params: { company: { modules: %w[ponto] } }
    expect(response).to have_http_status(:not_found)
  end

  it "does not register a company without the partner's contract" do
    sign_in_as(admin, "98765432100")

    get "/partner/companies/new"
    expect(response.body).to include("ainda não tem um contrato ativo")

    expect { post "/partner/companies", params: params }.not_to change(Company, :count)
    expect(response).to have_http_status(:unprocessable_content)
  end

  it "keeps the registration and the modules closed to the consultant (P-03-14)" do
    contract_for(partner)
    consultant = enable_mfa(create(:user, name: "Caio Consultor", cpf: "52998224725"))
    create(:membership, user: consultant, organization: partner, roles: %w[consultant])
      .partner_membership_companies.create!(company: padaria)
    sign_in_as(consultant, "52998224725")

    get "/partner"
    expect(response.body).not_to include("Cadastrar empresa")
    get "/partner/companies/new"
    expect(response).to have_http_status(:forbidden)
    post "/partner/companies", params: params
    expect(response).to have_http_status(:forbidden)
    patch "/partner/companies/#{padaria.id}/modules", params: { company: { modules: %w[ponto] } }
    expect(response).to have_http_status(:forbidden)
  end
end
