require "rails_helper"

# D-597: the sidebar's menus, with the prototype's modules not built yet as "Em breve",
# and the sidebar's text color by contrast with the brand's secondary color.
RSpec.describe "Navigation", type: :request do
  let(:partner) { create(:partner, name: "Aurora Gestão de Pessoas") }
  let(:brand) { create(:brand, owner: partner, commercial_name: "Aurora RH") }
  let(:padaria) { create(:company, partner: partner, name: "Padaria Pão Quente") }
  let(:transportes) { create(:company, partner: partner, name: "Transportes Rápidos") }
  let!(:user) { create(:user, cpf: "12345678909") }

  before do
    brand.subdomains.create!(slug: "aurora")
    Flipper.enable(FeatureFlags::SIGN_IN)
    publish_platform_legal_documents
    accept_legal_documents(user, brand)
    host! "aurora.painel.catalysthr.com.br"
  end

  def sign_in
    post "/sign-in", params: { user: { login: "12345678909", password: "Catalyst#2026" } }
  end

  # Changing the roles ends the open sessions (RN-02-063); the HR roles sign in with MFA.
  def sign_in_again
    reset!
    host! "aurora.painel.catalysthr.com.br"
    sign_in_with_mfa("12345678909", enable_mfa(user))
  end

  describe "in a company" do
    let!(:subscription) { contract_for(partner) }

    before do
      Flipper.enable(FeatureFlags::BILLING)
      turn_on_modules(padaria)
      create(:membership, user: user, organization: padaria, roles: %w[manager])
      sign_in
    end

    it "lists every module of the prototype, the ones not built yet as \"Em breve\"" do
      get "/"

      expect(response.body).to include("Painel", "Colaboradores", "Folha de pagamento", "Ponto eletrônico", "Integrações contábeis")
      expect(response.body.scan(">Em breve<").size).to eq(ComingSoon::COMPANY_FEATURES.size)
      expect(response.body).to include('href="/soon/payroll"')
    end

    it "opens the coming-soon page of a module, marked in the menu" do
      get "/soon/time-tracking"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("<title>Ponto eletrônico</title>", "Esta área ainda está em construção")
      expect(response.body).to match(%r{<a(?=[^>]*aria-current="page")(?=[^>]*href="/soon/time-tracking")})
    end

    it "answers 404 for a module that is not in the list" do
      get "/soon/recruitment"

      expect(response).to have_http_status(:not_found)
    end

    it "hides a module the partner turned off for the company, and does not open it (RN-19-012, D-616)" do
      turn_on_modules(padaria, %w[folha])

      get "/"
      expect(response.body).to include("Folha de pagamento")
      expect(response.body).not_to include("Ponto eletrônico")

      get "/soon/time-tracking"
      expect(response).to have_http_status(:not_found)
    end

    it "lists the modules as before the contracts while billing is off (D-610)" do
      Flipper.disable(FeatureFlags::BILLING)
      turn_on_modules(padaria, [])

      get "/"
      expect(response.body).to include("Folha de pagamento", "Ponto eletrônico")
      expect(response.body.scan(">Em breve<").size).to eq(ComingSoon::COMPANY_FEATURES.size)
    end

    it "hides the modules out of the contract (P-03-12, D-616)" do
      subscription.items.each { |item| item.update!(ends_on: Date.yesterday, starts_on: Date.yesterday) }

      get "/"
      expect(response.body).not_to include("Folha de pagamento", "Ponto eletrônico")
      expect(response.body).to include("Integrações contábeis")
    end

    it "shows the HR analyst only the modules released to them, and does not open the others (CA-03-001)" do
      Membership.find_by!(user: user).update!(roles: %w[hr_analyst], enabled_modules: %w[documentos])
      sign_in_again

      get "/"
      expect(response.body).to include("Documentos", "Assistente")
      expect(response.body).not_to include("Folha de pagamento", "Ponto eletrônico", "Admissões")

      get "/soon/payroll"
      expect(response).to have_http_status(:not_found)
    end

    it "does not restrict the HR administrator by released modules, only by the contract (CA-03-007)" do
      Membership.find_by!(user: user).update!(roles: %w[hr_admin])
      sign_in_again

      get "/"
      expect(response.body).to include("Folha de pagamento", "Ponto eletrônico", "Admissões")

      subscription.items.find_by!(module: "folha").update!(ends_on: Date.yesterday, starts_on: Date.yesterday)
      get "/"
      expect(response.body).not_to include("Folha de pagamento")
      expect(response.body).to include("Ponto eletrônico")
    end

    it "shows time tracking as available after the contract during the trial (CA-19-003, RN-19-031)" do
      subscription.update!(status: "trialing", trial_ends_on: Date.current + 5, activated_on: nil)

      get "/"
      expect(response.body).to match(%r{href="/soon/time-tracking".*?Após a contratação}m)
      expect(response.body).to match(%r{href="/soon/payroll".*?Em breve}m)

      get "/soon/time-tracking"
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Este módulo fica disponível depois da contratação",
        "A contratação é feita pelo parceiro que atende a sua empresa")
    end
  end

  it "sends to the company chooser before a company is chosen" do
    create(:membership, user: user, organization: padaria, roles: %w[manager])
    create(:membership, user: user, organization: transportes, roles: %w[manager])
    sign_in

    get "/soon/payroll"

    expect(response).to redirect_to("/companies")
  end

  describe "in the partner's panel" do
    before do
      create(:membership, user: user, organization: partner, roles: %w[partner_admin])
      enable_mfa(user)
      sign_in_with_mfa("12345678909", user)
    end

    # The models of process left "Em breve" with block 06b-1 (D-598, D-639).
    it "shows the partner's menu with the models of process" do
      get "/partner"

      expect(response.body).to include("Carteira", "Equipe", "Marca e domínio", 'href="/partner/process-templates"')
      expect(response.body).not_to include("Folha de pagamento", "Em breve")

      get "/partner/soon/process-templates"
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "the sidebar's text color (D-597)" do
    before do
      create(:membership, user: user, organization: padaria, roles: %w[manager])
    end

    it "is white on a dark secondary color" do
      sign_in
      get "/"

      expect(response.body).to include("--brand-on-secondary: #FFFFFF")
    end

    it "is dark on a light secondary color" do
      brand.update!(secondary_color: "#F4F7FA")
      sign_in
      get "/"

      expect(response.body).to include("--brand-on-secondary: #0C1E33")
    end
  end

  describe "in the admin area" do
    let!(:superadmin) { enable_mfa(create(:user, cpf: "52998224725", platform_role: "superadmin")) }

    it "shows the admin's menu, only with what the person may open" do
      host! "admin.catalysthr.com.br"
      sign_in_with_mfa("52998224725", superadmin)

      get "/"

      expect(response.body).to include("Marcas", "Ver como um usuário", "Termos e política")
      # Only the support enters a direct company (D-581)
      expect(response.body).not_to include("Entrar numa empresa direta", "Em breve")
    end
  end
end
