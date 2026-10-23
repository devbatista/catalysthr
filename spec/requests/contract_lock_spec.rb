require "rails_helper"

# Spec 19, RN-19-034, RN-19-051 and RN-19-052 (CA-19-006, D-613, D-624): in read only,
# nothing new is created or changed on the panel, for the contract and all its companies.
# The person's own account, paying and contracting stay open.
RSpec.describe "Contract read only", type: :request do
  around { |example| travel_to(Time.zone.local(2026, 10, 20, 10)) { example.run } }

  before do
    Flipper.enable(FeatureFlags::SIGN_IN)
    Flipper.enable(FeatureFlags::BILLING)
    publish_platform_legal_documents
  end

  def sign_in_member(organization, brand, roles, cpf: "98765432100")
    user = enable_mfa(create(:user, cpf: cpf))
    create(:membership, user: user, organization: organization, roles: roles)
    accept_legal_documents(user, brand)
    sign_in_with_mfa(cpf, user)
    user
  end

  describe "a partner 15 days late (CA-19-006)" do
    let(:partner) { create(:partner, name: "Aurora Gestão de Pessoas") }
    let(:brand) { create(:brand, owner: partner) }
    let(:company) { create(:company, partner: partner, name: "Metalúrgica Serra Azul") }
    let!(:subscription) { contract_for(partner, status: "read_only") }

    before do
      brand.subdomains.create!(slug: "aurora")
      host! "aurora.painel.catalysthr.com.br"
    end

    it "shows the client company's HR the limited access, without amounts, and refuses anything new (CA-03-006)" do
      sign_in_member(company, brand, %w[hr_admin])
      post "/current-company", params: { company_id: company.id }

      get "/"
      expect(response.body).to include("Acesso limitado por pendência com Aurora Gestão de Pessoas", "nada novo pode ser criado")
      expect(response.body).not_to include("Pagar a fatura", "R$")

      expect { post "/departments", params: { department: { name: "Produção", unit_id: company.headquarters.id } } }.not_to change { ActsAsTenant.without_tenant { Department.count } }
      expect(response).to redirect_to("/")
      expect(flash[:alert]).to eq("A conta está em somente leitura: nada novo pode ser criado ou alterado.")
    end

    it "shows the partner's administrator the way to pay, and keeps the person's own security open" do
      sign_in_member(partner, brand, %w[partner_admin])

      get "/partner"
      expect(response.body).to include("Conta em somente leitura por fatura vencida", "Pagar a fatura")

      patch "/security/password", params: { user: { current_password: "Catalyst#2026", password: "Nova#Senha2026",
        password_confirmation: "Nova#Senha2026" } }
      expect(flash[:alert]).to be_nil
    end

    it "opens everything again when the contract is active" do
      subscription.update!(status: "active")
      sign_in_member(company, brand, %w[hr_admin])
      post "/current-company", params: { company_id: company.id }

      get "/"
      expect(response.body).not_to include("Acesso limitado")
      expect { post "/departments", params: { department: { name: "Produção", unit_id: company.headquarters.id } } }.to change { ActsAsTenant.without_tenant { Department.count } }.by(1)
    end

    it "locks nothing while billing is off (D-610)" do
      Flipper.disable(FeatureFlags::BILLING)
      sign_in_member(company, brand, %w[hr_admin])
      post "/current-company", params: { company_id: company.id }

      expect { post "/departments", params: { department: { name: "Produção", unit_id: company.headquarters.id } } }.to change { ActsAsTenant.without_tenant { Department.count } }.by(1)
    end
  end

  describe "a direct company whose trial ended (RN-19-034, D-613)" do
    let(:company) { create(:company, name: "Metalúrgica Serra Azul") }
    let(:brand) { create(:brand, owner: company) }
    let!(:subscription) { contract_for(company, status: "trial_expired") }

    before do
      brand.subdomains.create!(slug: "serraazul")
      host! "serraazul.painel.catalysthr.com.br"
    end

    it "is read only, with the way to contract, which stays open" do
      plan = create(:plan_version, plan: create(:plan, :direct, name: "Essencial")).plan
      sign_in_member(company, brand, %w[hr_admin])

      get "/"
      expect(response.body).to include("O teste grátis terminou e a conta está em somente leitura", "Contratar")
      expect { post "/departments", params: { department: { name: "Produção", unit_id: company.headquarters.id } } }.not_to change { ActsAsTenant.without_tenant { Department.count } }

      post "/contract", params: { plan_id: plan.id, modules: %w[folha] }
      expect(Invoice.find_by(checkout: true)).to be_present
    end
  end
end
