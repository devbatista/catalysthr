require "rails_helper"

# Spec 02, RN-02-070 to RN-02-073 and CA-02-011: the company's accounting firm, its
# area and its team (D-584, D-586, D-588 to D-590).
RSpec.describe "Accounting firm", type: :request do
  include ActiveJob::TestHelper

  let(:partner) { create(:partner) }
  let(:brand) { create(:brand, owner: partner, commercial_name: "Aurora RH") }
  let!(:padaria) { create(:company, partner: partner, name: "Padaria Pão Quente") }
  let!(:transportes) { create(:company, partner: partner, name: "Transportes Rápidos") }
  let(:serra_azul) { create(:company, name: "Metalúrgica Serra Azul") }
  let(:serra_azul_brand) { create(:brand, owner: serra_azul, commercial_name: "Serra Azul RH") }

  before do
    brand.subdomains.create!(slug: "aurora")
    serra_azul_brand.subdomains.create!(slug: "serraazul")
    Flipper.enable(FeatureFlags::SIGN_IN)
    publish_platform_legal_documents
    host! "aurora.painel.catalysthr.com.br"
  end

  def sign_in_as(user, cpf, brand: self.brand)
    accept_legal_documents(user, brand)
    user.otp_required_for_login ? sign_in_with_mfa(cpf, user) : post("/sign-in", params: { user: { login: cpf, password: "Catalyst#2026" } })
  end

  def firm_with(admin_cpf: "11144477735", links: {})
    firm = create(:accounting_firm, name: "Contábil Exata")
    admin = create(:user, name: "Eva Contadora", cpf: admin_cpf, email: "eva@exata.example")
    create(:membership, user: admin, organization: firm, roles: %w[firm_admin])
    links.each { |company, status| create(:accounting_firm_company, accounting_firm: firm, company: company, status: status) }
    [ firm, admin ]
  end

  describe "the company's HR administrator (RN-02-070, RN-02-073)" do
    let!(:hr_admin) { enable_mfa(create(:user, name: "Rita RH", cpf: "98765432100")) }

    before do
      create(:membership, user: hr_admin, organization: padaria, roles: %w[hr_admin])
      sign_in_as(hr_admin, "98765432100")
    end

    def link_firm(**overrides)
      post "/accounting-firm", params: { accounting_firm: { name: "Contábil Exata", cnpj: "11222333000181",
        admin_name: "Eva Contadora", admin_cpf: "11144477735", admin_email: "eva@exata.example",
        channels: %w[email link] }.merge(overrides) }
    end

    it "registers a new firm, links it at once and invites its administrator (D-588)" do
      perform_enqueued_jobs { link_firm }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Contábil Exata cadastrado", "http://aurora.painel.catalysthr.com.br/invitation?token=", "<svg")
      firm = AccountingFirm.find_by!(cnpj: "11222333000181")
      expect(firm.accounting_firm_companies.sole).to have_attributes(company: padaria, status: "active", linked_by: hr_admin)
      expect(firm.memberships.sole).to have_attributes(roles: %w[firm_admin], status: "invited")
      mail = ActionMailer::Base.deliveries.last
      expect(mail.to).to eq([ "eva@exata.example" ])
      expect(mail[:from].display_names).to eq([ "Aurora RH" ])
      expect(AccessEvent.find_by!(action: "accounting_firm_linked").company).to eq(padaria)
    end

    it "asks an existing firm to accept, telling its administrators (CA-02-011, D-590)" do
      firm, = firm_with(admin_cpf: "52998224725")

      perform_enqueued_jobs { link_firm(cnpj: firm.cnpj, admin_cpf: "11144477735") }

      expect(response.body).to include("Pedido enviado para Contábil Exata")
      expect(firm.accounting_firm_companies.sole).to have_attributes(company: padaria, status: "pending")
      expect(User.find_by(cpf: "11144477735")).to be_nil
      mail = ActionMailer::Base.deliveries.last
      expect(mail.to).to eq([ "eva@exata.example" ])
      expect(mail.subject).to eq("Padaria Pão Quente pediu para ligar o seu escritório contábil")
      expect(mail.body.encoded).to include("http://aurora.painel.catalysthr.com.br/firm")
    end

    it "keeps one firm per company (D-589)" do
      link_firm
      get "/accounting-firm/new"
      expect(response).to redirect_to("/accounting-firm")

      link_firm(cnpj: "11444777000161", admin_cpf: "52998224725")
      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("já tem um escritório contábil ligado")
    end

    it "shows the errors and saves nothing when the data is invalid" do
      link_firm(admin_cpf: "123")

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("CPF não é um CPF válido")
      expect(AccountingFirm.count).to eq(0)
    end

    it "resends the first invitation while the firm has no active administrator" do
      link_firm
      membership = AccountingFirm.sole.memberships.sole

      get "/accounting-firm"
      expect(response.body).to include("Reenviar o convite para Eva Contadora")
      post "/accounting-firm/resend-invitation", params: { membership_id: membership.id, channels: %w[link] }

      expect(response.body).to include("http://aurora.painel.catalysthr.com.br/invitation?token=")
    end

    it "ends the link, and the accountants lose the company at once (RN-02-073)" do
      firm, accountant = firm_with(links: { padaria => "active" })
      delete "/accounting-firm"

      expect(response).to redirect_to("/accounting-firm")
      expect(firm.accounting_firm_companies.sole).to have_attributes(status: "ended")
      expect(AccessEvent.find_by!(action: "accounting_firm_unlinked").user).to eq(hr_admin)

      reset!
      host! "aurora.painel.catalysthr.com.br"
      post "/sign-in", params: { user: { login: accountant.cpf, password: "Catalyst#2026" } }
      expect(response.body).to include("CPF, e-mail ou senha inválidos")
    end
  end

  it "keeps the company's firm closed to an HR analyst" do
    analyst = enable_mfa(create(:user, cpf: "98765432100"))
    create(:membership, user: analyst, organization: padaria, roles: %w[hr_analyst])
    sign_in_as(analyst, "98765432100")

    get "/accounting-firm"

    expect(response).to have_http_status(:forbidden)
  end

  describe "the firm's area (RN-02-072, D-586)" do
    it "opens the area with the brand's companies only, and lets the accountant into the active ones" do
      firm, = firm_with(links: { padaria => "active", transportes => "pending", serra_azul => "active" })
      accountant = create(:user, name: "Caio Contador", cpf: "52998224725")
      create(:membership, user: accountant, organization: firm, roles: %w[accountant])
      sign_in_as(accountant, "52998224725")

      get "/"
      expect(response).to redirect_to("/firm")
      get "/firm"
      expect(response.body).to include("Contábil Exata", "Padaria Pão Quente", "Transportes Rápidos")
      expect(response.body).not_to include("Metalúrgica Serra Azul", "Equipe", "Aceitar")

      post "/current-company", params: { company_id: transportes.id }
      expect(response).to have_http_status(:not_found)
      post "/current-company", params: { company_id: padaria.id }
      get "/"
      expect(response.body).to include("Empresa: Padaria Pão Quente.")
    end

    it "does not let the team sign in at a brand the firm does not serve" do
      _firm, admin = firm_with(links: { padaria => "active" })
      host! "serraazul.painel.catalysthr.com.br"

      post "/sign-in", params: { user: { login: admin.cpf, password: "Catalyst#2026" } }

      expect(response.body).to include("CPF, e-mail ou senha inválidos")
    end

    it "lets the administrator accept or refuse the brand's requests (P-02-29, D-590)" do
      firm, admin = firm_with(links: { padaria => "pending", transportes => "pending" })
      sign_in_as(admin, admin.cpf)
      padaria_link, transportes_link = firm.accounting_firm_companies.order(:id)

      post "/firm/links/#{padaria_link.id}/accept"
      expect(response).to redirect_to("/firm")
      expect(padaria_link.reload).to have_attributes(status: "active")

      post "/firm/links/#{transportes_link.id}/refuse"
      expect(transportes_link.reload).to have_attributes(status: "ended")
      expect(AccessEvent.where(kind: "admin").pluck(:action))
        .to include("accounting_firm_link_accepted", "accounting_firm_link_refused")
    end

    it "does not find another brand's request" do
      firm, admin = firm_with(links: { padaria => "active", serra_azul => "pending" })
      sign_in_as(admin, admin.cpf)

      post "/firm/links/#{firm.accounting_firm_companies.find_by!(company: serra_azul).id}/accept"

      expect(response).to have_http_status(:not_found)
    end

    it "keeps the requests closed to an accountant" do
      firm, = firm_with(links: { padaria => "pending", transportes => "active" })
      accountant = create(:user, cpf: "52998224725")
      create(:membership, user: accountant, organization: firm, roles: %w[accountant])
      sign_in_as(accountant, "52998224725")

      post "/firm/links/#{firm.accounting_firm_companies.find_by!(company: padaria).id}/accept"

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "the firm's team (RN-02-071, RN-02-044, D-584)" do
    let!(:firm_and_admin) { firm_with(links: { padaria => "active" }) }
    let(:firm) { firm_and_admin.first }

    before { sign_in_as(firm_and_admin.last, "11144477735") }

    it "invites an accountant with a link to this brand's address (D-586)" do
      perform_enqueued_jobs do
        post "/firm/team", params: { invitation: { name: "Caio Contador", cpf: "52998224725", email: "caio@exata.example",
          roles: %w[accountant consultant], channels: %w[email link] } }
      end

      expect(response.body).to include("Convite criado para Caio Contador", "http://aurora.painel.catalysthr.com.br/invitation?token=")
      expect(firm.memberships.find_by!(user: User.find_by!(cpf: "52998224725")).roles).to eq(%w[accountant])
      mail = ActionMailer::Base.deliveries.last
      expect(mail[:from].display_names).to eq([ "Aurora RH" ])
      expect(mail.body.encoded).to include("http://aurora.painel.catalysthr.com.br/invitation?token=")
    end

    it "resets an accountant's MFA, but leaves another administrator's to the support" do
      accountant = create(:membership, organization: firm, roles: %w[accountant], user: enable_mfa(create(:user)))
      other_admin = create(:membership, organization: firm, roles: %w[firm_admin], user: enable_mfa(create(:user)))

      get "/firm/team/#{accountant.id}"
      expect(response.body).to include("Redefinir a verificação em duas etapas")
      expect(response.body).not_to include("Corrigir o contato")

      post "/firm/team/#{accountant.id}/reset-mfa"
      expect(accountant.user.reload.mfa_enabled?).to be(false)

      post "/firm/team/#{other_admin.id}/reset-mfa"
      expect(response).to have_http_status(:forbidden)
    end

    it "lets the person accept the invitation at this brand" do
      invitation = Invitations::Create.call(organization: firm, roles: %w[accountant], channels: %w[link],
        invited_by: firm_and_admin.last, name: "Caio Contador", cpf: "52998224725", mobile_phone: "11987654321", brand: brand)
      reset!
      host! "aurora.painel.catalysthr.com.br"

      get "/invitation", params: { token: invitation.token }

      expect(response.body).to include("Olá, Caio.")
    end
  end
end
