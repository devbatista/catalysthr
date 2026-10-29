require "rails_helper"

# Spec 19, RN-19-041 and RN-19-044 (D-619): the invoices with every line, for the
# CatalystHR team in the admin, for the partner's administrator and for the direct
# company's HR administrator, each seeing only its own contract.
RSpec.describe "Invoices", type: :request do
  around { |example| travel_to(Time.zone.local(2026, 10, 15, 10)) { example.run } }

  before do
    Flipper.enable(FeatureFlags::SIGN_IN)
    Flipper.enable(FeatureFlags::BILLING)
    publish_platform_legal_documents
  end

  def first_invoice(subscription)
    Billing::Invoicing.issue_due(subscription, Date.current, lead: 0).sole
  end

  describe "in the admin" do
    let!(:partner_plan) { create(:plan_version, plan: create(:plan, name: "Até 500 colaboradores")).plan }

    before { host! "admin.catalysthr.com.br" }

    def sign_in(role)
      user = enable_mfa(create(:user, platform_role: role, cpf: "52998224725", name: "Paulo Lima"))
      sign_in_with_mfa("52998224725", user)
    end

    it "issues the first cycle's invoice when a contract is registered, due that day (D-619)" do
      create(:pre_activation_price, monthly_price_cents: 1_990)
      sign_in("finance")

      post "/clients", params: { client: BillingHelpers::BILLING_ADDRESS.merge(
        kind: "partner", mode: "contract", legal_name: "Aurora Gestão de Pessoas Ltda", commercial_name: "Aurora RH",
        cnpj: "11.222.333/0001-81", slug: "aurora", plan_id: partner_plan.id, modules: [ "ponto" ],
        admin_name: "Ana Prado", admin_cpf: "111.444.777-35", admin_email: "ana@aurora.example"
      ) }

      invoice = Invoice.sole
      expect(invoice).to have_attributes(due_on: Date.new(2026, 10, 15), period_start: Date.new(2026, 10, 15), total_cents: 1_990)
      expect(Notification.where(notification_type: "billing.invoice_issued").sole.recipient_user.cpf).to eq("11144477735")

      follow_redirect!
      expect(response.body).to include("Faturas", "000001", "R$ 19,90", "Em aberto")
    end

    it "lists every contract's invoices and shows the lines to the finance team and the support (spec 19, section 6)" do
      invoice = first_invoice(contract_for(create(:partner, name: "Aurora Gestão de Pessoas")))
      sign_in("support")

      get "/"
      expect(response.body).to include(">Faturas<")
      get "/invoices"
      expect(response.body).to include("000001", "Aurora Gestão de Pessoas", "R$ 2.500,00")
      get "/invoices/#{invoice.id}"
      expect(response.body).to include("Fatura 000001", "Módulo Ponto", "Módulo Folha", "15/10/2026 – 14/11/2026")
    end

    it "hides the invoices while billing is off (D-610)" do
      sign_in("finance")
      Flipper.disable(FeatureFlags::BILLING)

      get "/invoices"
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "in the partner's panel" do
    let(:partner) { create(:partner, name: "Aurora Gestão de Pessoas") }
    let(:brand) { create(:brand, owner: partner, commercial_name: "Aurora RH") }
    let!(:invoice) { first_invoice(contract_for(partner)) }
    let!(:other_invoice) { first_invoice(contract_for(create(:partner, name: "Outro Parceiro"))) }

    before do
      brand.subdomains.create!(slug: "aurora")
      host! "aurora.painel.catalysthr.com.br"
    end

    def sign_in_member(roles)
      user = enable_mfa(create(:user, cpf: "98765432100"))
      create(:membership, user: user, organization: partner, roles: roles)
      accept_legal_documents(user, brand)
      sign_in_with_mfa("98765432100", user)
    end

    it "shows the administrator the partner's own invoices only" do
      sign_in_member(%w[partner_admin])

      get "/partner"
      expect(response.body).to include(">Faturas<")
      get "/partner/invoices"
      expect(response.body).to include("000001", "R$ 2.500,00")
      expect(response.body).not_to include("000002")
      get "/partner/invoices/#{invoice.id}"
      expect(response.body).to include("Plano #{invoice.billing_account.subscription.plan.name}", "O PIX desta fatura não está disponível agora")
      get "/partner/invoices/#{other_invoice.id}"
      expect(response).to have_http_status(:not_found)
    end

    it "keeps the invoices closed to the consultant" do
      sign_in_member(%w[consultant])

      get "/partner"
      expect(response.body).not_to include(">Faturas<")
      get "/partner/invoices"
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "in a direct company" do
    let(:company) { create(:company, name: "Metalúrgica Serra Azul") }
    let(:brand) { create(:brand, owner: company, commercial_name: "Serra Azul") }
    let!(:invoice) { first_invoice(contract_for(company)) }

    before do
      brand.subdomains.create!(slug: "serraazul")
      host! "serraazul.painel.catalysthr.com.br"
    end

    def sign_in_member(roles, organization: company)
      user = enable_mfa(create(:user, cpf: "98765432100"))
      create(:membership, user: user, organization: organization, roles: roles)
      accept_legal_documents(user, brand)
      sign_in_with_mfa("98765432100", user)
    end

    it "shows the HR administrator the company's invoices" do
      sign_in_member(%w[hr_admin])

      get "/"
      expect(response.body).to include(">Faturas<")
      get "/invoices"
      expect(response.body).to include("000001", "R$ 300,00")
      get "/invoices/#{invoice.id}"
      expect(response.body).to include("mínimo mensal (nenhum colaborador ativo)")
    end

    it "shows the HR administrator the invoice's PIX to pay, with the code to copy (RN-19-042, D-622)" do
      configure_mercado_pago
      invoice.billing_account.update!(billing_email: "financeiro@serraazul.example")
      stub_create_order
      sign_in_member(%w[hr_admin])

      get "/invoices/#{invoice.id}"

      payment = invoice.payments.sole
      expect(response.body).to include("Pagar com PIX", "PIX copia e cola", payment.qr_code, "Copiar código", "Abrir no Mercado Pago",
        "PIX de R$ 300,00, válido até 15/10/2026 às 23h59", "data:image/png;base64,#{payment.qr_code_base64}")
      get "/invoices/#{invoice.id}"
      expect(invoice.payments.count).to eq(1)
    end

    it "tells the HR administrator when Mercado Pago is out of the air" do
      configure_mercado_pago
      stub_request(:post, MercadoPagoStub::ORDERS_URL).to_return(status: 503, body: "{}")
      sign_in_member(%w[hr_admin])

      get "/invoices/#{invoice.id}"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("O PIX desta fatura não está disponível agora")
    end

    it "shows the paid invoice without a PIX" do
      invoice.update!(status: "paid", paid_at: Time.current)
      sign_in_member(%w[hr_admin])

      get "/invoices/#{invoice.id}"

      expect(response.body).to include("Fatura paga em 15/10/2026", "Paga")
      expect(response.body).not_to include("Pagar com PIX")
    end

    it "keeps the invoices closed to the HR analyst" do
      sign_in_member(%w[hr_analyst])

      get "/"
      expect(response.body).not_to include(">Faturas<")
      get "/invoices"
      expect(response).to have_http_status(:forbidden)
    end
  end

  it "gives a partner's client company no invoices: the partner's contract pays (RN-19-001)" do
    partner = create(:partner)
    brand = create(:brand, owner: partner)
    brand.subdomains.create!(slug: "aurora")
    first_invoice(contract_for(partner))
    company = create(:company, partner: partner)
    host! "aurora.painel.catalysthr.com.br"
    user = enable_mfa(create(:user, cpf: "98765432100"))
    create(:membership, user: user, organization: company, roles: %w[hr_admin])
    accept_legal_documents(user, brand)
    sign_in_with_mfa("98765432100", user)
    post "/current-company", params: { company_id: company.id }

    get "/"
    expect(response.body).not_to include(">Faturas<")
    get "/invoices"
    expect(response).to have_http_status(:forbidden)
  end
end
