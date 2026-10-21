require "rails_helper"

# Spec 19, RN-19-033 and RN-19-034 (D-622): the financial responsible contracts during the
# trial or after it, on the panel, and pays the first invoice by PIX.
RSpec.describe "Contracting", type: :request do
  around { |example| travel_to(Time.zone.local(2026, 10, 20, 10)) { example.run } }

  before do
    Flipper.enable(FeatureFlags::SIGN_IN)
    Flipper.enable(FeatureFlags::BILLING)
    publish_platform_legal_documents
    configure_mercado_pago
  end

  def sign_in_member(organization, brand, roles)
    user = enable_mfa(create(:user, cpf: "98765432100"))
    create(:membership, user: user, organization: organization, roles: roles)
    accept_legal_documents(user, brand)
    sign_in_with_mfa("98765432100", user)
  end

  describe "in a direct company" do
    let(:company) { create(:company, name: "Metalúrgica Serra Azul") }
    let(:brand) { create(:brand, owner: company) }
    let!(:subscription) { contract_for(company, status: "trialing", modules: %w[folha]) }
    let!(:plan) { create(:plan_version, plan: create(:plan, :direct, name: "Essencial")).plan }

    before do
      brand.subdomains.create!(slug: "serraazul")
      host! "serraazul.painel.catalysthr.com.br"
      subscription.billing_account.update!(billing_email: "financeiro@serraazul.example")
    end

    it "lets the HR administrator choose the plan and pay the first invoice by PIX (RN-19-033)" do
      stub_create_order
      sign_in_member(company, brand, %w[hr_admin])

      get "/"
      expect(response.body).to include(">Contratar<")
      get "/contract/new"
      expect(response.body).to include("Seu teste grátis vai até 03/11/2026", "Essencial", "Ponto", "Contratar e pagar com PIX")

      post "/contract", params: { plan_id: plan.id, modules: %w[ponto folha] }

      invoice = Invoice.find_by!(checkout: true)
      expect(response).to redirect_to("/invoices/#{invoice.id}")
      follow_redirect!
      expect(response.body).to include("Pague o PIX abaixo até 23h59 de hoje", "Pagar com PIX", "Esta é a fatura da contratação")
      expect(subscription.reload).to be_trialing

      get "/contract/new"
      expect(response.body).to include("aguardando o PIX de hoje", "Ver a fatura")
    end

    it "shows the choice again when the plan is not offered" do
      sign_in_member(company, brand, %w[hr_admin])

      post "/contract", params: { plan_id: create(:plan_version, plan: create(:plan, name: "Parceiro 500")).plan_id, modules: [] }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("Não foi possível contratar com essa escolha")
      expect(Invoice.count).to eq(0)
    end

    it "hides the contracting once the contract is active" do
      subscription.update!(status: "active")
      sign_in_member(company, brand, %w[hr_admin])

      get "/"
      expect(response.body).not_to include(">Contratar<")
      get "/contract/new"
      expect(response).to redirect_to("/invoices")
    end

    it "keeps the contracting closed to the HR analyst and while billing is off" do
      sign_in_member(company, brand, %w[hr_analyst])

      get "/contract/new"
      expect(response).to have_http_status(:forbidden)
      Flipper.disable(FeatureFlags::BILLING)
      get "/contract/new"
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "in the partner's panel" do
    let(:partner) { create(:partner, name: "Aurora Gestão de Pessoas") }
    let(:brand) { create(:brand, owner: partner) }
    let!(:subscription) { contract_for(partner, status: "trial_expired") }

    before do
      create(:pre_activation_price, monthly_price_cents: 1_990)
      brand.subdomains.create!(slug: "aurora")
      host! "aurora.painel.catalysthr.com.br"
    end

    it "lets the administrator contract after the trial, on the pre-activation fee (RN-19-034, RN-19-035)" do
      sign_in_member(partner, brand, %w[partner_admin])

      get "/partner/contract/new"
      expect(response.body).to include("O teste terminou em", "Contratando, tudo volta a funcionar", "pré-ativação, de R$ 19,90")

      post "/partner/contract", params: { plan_id: subscription.plan.id, modules: %w[ponto] }

      invoice = Invoice.find_by!(checkout: true)
      expect(response).to redirect_to("/partner/invoices/#{invoice.id}")
      expect(invoice.total_cents).to eq(1_990)
    end

    it "keeps the contracting closed to the consultant" do
      sign_in_member(partner, brand, %w[consultant])

      get "/partner/contract/new"
      expect(response).to have_http_status(:forbidden)
    end
  end
end
