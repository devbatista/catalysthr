require "rails_helper"

# Spec 03, section 4.1, and spec 01, RN-01-004, RN-01-005 and RN-01-011: the partner's
# panel, its team and the HR of the client companies (D-052, D-192, D-584, D-585).
RSpec.describe "Partner's panel", type: :request do
  include ActiveJob::TestHelper

  let(:partner) { create(:partner, name: "Aurora Gestão de Pessoas") }
  let(:brand) { create(:brand, owner: partner, commercial_name: "Aurora RH") }
  let!(:padaria) { create(:company, partner: partner, name: "Padaria Pão Quente") }
  let!(:transportes) { create(:company, partner: partner, name: "Transportes Rápidos") }
  let!(:outsider) { create(:company, :with_partner, name: "Cliente de Outro Parceiro") }
  let!(:admin) { enable_mfa(create(:user, name: "Paula Admin", cpf: "98765432100")) }

  before do
    create(:membership, user: admin, organization: partner, roles: %w[partner_admin])
    brand.subdomains.create!(slug: "aurora")
    Flipper.enable(FeatureFlags::SIGN_IN)
    publish_platform_legal_documents
    host! "aurora.painel.catalysthr.com.br"
  end

  def sign_in_as(user, cpf)
    accept_legal_documents(user, brand)
    sign_in_with_mfa(cpf, user)
  end

  def consultant_with(companies, modules: [])
    user = enable_mfa(create(:user, name: "Caio Consultor", cpf: "11144477735"))
    membership = create(:membership, user: user, organization: partner, roles: %w[consultant], enabled_modules: modules)
    companies.each { |company| membership.partner_membership_companies.create!(company: company) }
    membership
  end

  describe "the portfolio (RN-01-004, RN-01-011)" do
    it "opens the partner's panel with all the partner's companies for the administrator" do
      sign_in_as(admin, "98765432100")

      get "/"
      expect(response).to redirect_to("/partner")
      get "/partner"
      expect(response.body).to include("Padaria Pão Quente", "Transportes Rápidos", "Equipe")
      expect(response.body).not_to include("Cliente de Outro Parceiro")
    end

    it "keeps the administrator without the consultant role out of the companies (P-03-01)" do
      sign_in_as(admin, "98765432100")

      post "/current-company", params: { company_id: padaria.id }

      expect(response).to have_http_status(:not_found)
    end

    it "shows the consultant only the assigned companies and lets them in (CA-01-003, D-192)" do
      consultant = consultant_with([ padaria ]).user
      sign_in_as(consultant, "11144477735")

      get "/"
      expect(response).to redirect_to("/partner")
      get "/partner"
      expect(response.body).to include("Padaria Pão Quente")
      expect(response.body).not_to include("Transportes Rápidos", "Equipe")

      post "/current-company", params: { company_id: transportes.id }
      expect(response).to have_http_status(:not_found)

      post "/current-company", params: { company_id: padaria.id }
      get "/"
      expect(response.body).to include("Empresa: Padaria Pão Quente.")
      get "/users"
      expect(response).to have_http_status(:forbidden)
    end

    it "ends the consultant's access to a company taken away, at the next request (RN-01-005)" do
      membership = consultant_with([ padaria, transportes ])
      sign_in_as(membership.user, "11144477735")
      post "/current-company", params: { company_id: padaria.id }

      membership.partner_membership_companies.find_by!(company: padaria).destroy!
      get "/"

      expect(response.body).not_to include("Empresa: Padaria Pão Quente.")
    end
  end

  describe "the team (D-052, P-03-06, D-584)" do
    before { sign_in_as(admin, "98765432100") }

    it "invites a consultant with modules and companies, from the partner's address" do
      perform_enqueued_jobs do
        post "/partner/team", params: { invitation: { name: "Caio Consultor", cpf: "11144477735", email: "caio@example.com",
          roles: %w[consultant hr_admin], enabled_modules: %w[admissao], company_ids: [ padaria.id, outsider.id ],
          channels: %w[email link] } }
      end

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Convite criado para Caio Consultor", "http://aurora.painel.catalysthr.com.br/invitation?token=")
      membership = Membership.find_by!(user: User.find_by!(cpf: "11144477735"))
      expect(membership).to have_attributes(organization: partner, roles: %w[consultant], enabled_modules: %w[admissao])
      expect(membership.assigned_companies).to contain_exactly(padaria)
      expect(ActionMailer::Base.deliveries.last.to).to eq([ "caio@example.com" ])
    end

    it "changes the consultant's companies, recording the change" do
      membership = consultant_with([ padaria ])

      patch "/partner/team/#{membership.id}", params: { membership: { roles: %w[consultant], company_ids: [ transportes.id ] } }

      expect(response).to redirect_to("/partner/team/#{membership.id}")
      expect(membership.assigned_companies.reload).to contain_exactly(transportes)
      expect(AccessEvent.find_by!(action: "companies_assigned").metadata)
        .to eq("from" => [ padaria.id ], "to" => [ transportes.id ])
    end

    it "drops the companies of who stops being a consultant" do
      membership = consultant_with([ padaria ])

      patch "/partner/team/#{membership.id}", params: { membership: { roles: %w[partner_admin], company_ids: [ padaria.id ] } }

      expect(membership.reload.roles).to eq(%w[partner_admin])
      expect(membership.assigned_companies).to be_empty
    end

    it "lists only this partner's team and answers 403 for one's own access" do
      consultant_with([])
      create(:membership, organization: create(:partner), roles: %w[consultant], user: create(:user, name: "Pessoa de Fora"))
      own = Membership.find_by!(user: admin)

      get "/partner/team"
      expect(response.body).to include("Paula Admin", "Caio Consultor")
      expect(response.body).not_to include("Pessoa de Fora")

      patch "/partner/team/#{own.id}", params: { membership: { roles: %w[consultant] } }
      expect(response).to have_http_status(:forbidden)
    end

    it "opens the team's pages with the partner's roles, modules and companies" do
      membership = consultant_with([ padaria ], modules: %w[ponto])

      get "/partner/team/new"
      expect(response.body).to include("Convidar para a equipe", "Administrador do parceiro", "Módulos do consultor",
        "Empresas do consultor", "Padaria Pão Quente")
      expect(response.body).not_to include("Cliente de Outro Parceiro")

      get "/partner/team/#{membership.id}"
      expect(response.body).to include("Caio Consultor", "Empresas atribuídas", "Padaria Pão Quente", "Voltar para a equipe",
        "Redefinir a verificação em duas etapas")

      get "/partner/team/#{membership.id}/edit"
      expect(response.body).to include("Perfis de Caio Consultor", %(value="#{padaria.id}" checked))
    end

    it "resets the consultant's MFA (RN-02-044)" do
      membership = consultant_with([])

      post "/partner/team/#{membership.id}/reset-mfa"

      expect(response).to redirect_to("/partner/team/#{membership.id}")
      expect(membership.user.reload.mfa_enabled?).to be(false)
    end

    it "removes a consultant" do
      membership = consultant_with([ padaria ])

      delete "/partner/team/#{membership.id}"

      expect(response).to redirect_to("/partner/team")
      expect(membership.reload).to be_revoked
      expect(membership.assigned_companies).to be_empty
    end
  end

  it "keeps the team closed to the consultant" do
    consultant = consultant_with([ padaria ]).user
    sign_in_as(consultant, "11144477735")

    get "/partner/team"

    expect(response).to have_http_status(:forbidden)
  end

  describe "the HR of the client companies (P-03-35, D-585)" do
    let!(:hr_admin) { create(:membership, organization: padaria, roles: %w[hr_admin], user: create(:user, name: "Rita RH")) }

    before do
      create(:membership, organization: padaria, roles: %w[hr_analyst], user: create(:user, name: "Ana Analista"))
      sign_in_as(admin, "98765432100")
    end

    it "lists only the company's HR administrators" do
      get "/partner/companies/#{padaria.id}/hr-admins"

      expect(response.body).to include("RH administradores de Padaria Pão Quente", "Rita RH")
      expect(response.body).not_to include("Ana Analista")
    end

    it "opens the pages without modules, contact or MFA, which stay with the company (P-03-06, RN-02-044)" do
      get "/partner/companies/#{padaria.id}/hr-admins/new"
      expect(response.body).to include("Convidar RH administrador")
      expect(response.body).not_to include("Módulos do RH analista", "Perfis")

      get "/partner/companies/#{padaria.id}/hr-admins/#{hr_admin.id}"
      expect(response.body).to include("Rita RH", "Alterar perfis", "Voltar para o RH da empresa")
      expect(response.body).not_to include("Corrigir o contato", "Redefinir a verificação", "feitas pelo suporte")

      get "/partner/companies/#{padaria.id}/hr-admins/#{hr_admin.id}/edit"
      expect(response.body).to include("RH administrador", "RH analista", "Gestor")
      expect(response.body).not_to include("Módulos do RH analista")
    end

    it "invites a new HR administrator" do
      perform_enqueued_jobs do
        post "/partner/companies/#{padaria.id}/hr-admins", params: { invitation: { name: "Joana Prado", cpf: "11144477735",
          email: "joana@example.com", roles: %w[hr_admin consultant], channels: %w[email] } }
      end

      expect(response).to have_http_status(:ok)
      membership = Membership.find_by!(user: User.find_by!(cpf: "11144477735"))
      expect(membership).to have_attributes(organization: padaria, roles: %w[hr_admin], status: "invited")
      expect(ActionMailer::Base.deliveries.last.to).to eq([ "joana@example.com" ])
    end

    it "changes an HR administrator's roles, without touching the modules" do
      patch "/partner/companies/#{padaria.id}/hr-admins/#{hr_admin.id}",
        params: { membership: { roles: %w[hr_analyst], enabled_modules: %w[folha] } }

      expect(response).to redirect_to("/partner/companies/#{padaria.id}/hr-admins")
      expect(hr_admin.reload).to have_attributes(roles: %w[hr_analyst], enabled_modules: [])
    end

    it "removes an HR administrator" do
      delete "/partner/companies/#{padaria.id}/hr-admins/#{hr_admin.id}"

      expect(hr_admin.reload).to be_revoked
    end

    it "does not find another partner's company (RN-01-013)" do
      get "/partner/companies/#{outsider.id}/hr-admins"

      expect(response).to have_http_status(:not_found)
    end

    it "does not let the administrator change their own HR access (RN-03-012)" do
      own = create(:membership, user: admin, organization: transportes, roles: %w[hr_admin])

      delete "/partner/companies/#{transportes.id}/hr-admins/#{own.id}"

      expect(response).to have_http_status(:forbidden)
      expect(own.reload).to be_active
    end
  end

  it "keeps the companies' HR closed to the consultant" do
    consultant = consultant_with([ padaria ]).user
    sign_in_as(consultant, "11144477735")

    get "/partner/companies/#{padaria.id}/hr-admins"

    expect(response).to have_http_status(:forbidden)
  end
end
