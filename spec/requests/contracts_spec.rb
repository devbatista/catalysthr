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

    it "fills the missing billing address with the headquarters' at the checkout, then keeps them apart (D-635)" do
      stub_create_order
      ActsAsTenant.with_tenant(company) do
        company.headquarters.update!(postal_code: "01310100", street: "Avenida Paulista", street_number: "1000", district: "Bela Vista",
          city: "São Paulo", state: "SP")
      end
      subscription.billing_account.update_columns(postal_code: nil, street: nil, street_number: nil, district: nil, city: nil, state: nil)
      sign_in_member(company, brand, %w[hr_admin])

      get "/contract/new"
      expect(response.body).to include("Endereço de cobrança", 'value="Avenida Paulista"', 'value="01310100"')

      post "/contract", params: { plan_id: plan.id, modules: %w[folha], billing_account: { postal_code: "01310-100", street: "Avenida Paulista",
        street_number: "1000", complement: "Conj. 12", district: "Bela Vista", city: "São Paulo", state: "SP" } }

      expect(response).to redirect_to("/invoices/#{Invoice.find_by!(checkout: true).id}")
      account = subscription.billing_account.reload
      expect(account.complement).to eq("Conj. 12")
      ActsAsTenant.with_tenant(company) { company.headquarters.update!(street_number: "2000") }
      expect(account.reload.street_number).to eq("1000")
    end

    it "lets the HR administrator change the billing address on the invoices, not the HR analyst (D-635)" do
      sign_in_member(company, brand, %w[hr_admin])

      get "/invoices"
      expect(response.body).to include("Endereço de cobrança", "Alterar")
      get "/contract/billing-address/edit"
      expect(response.body).to include("Buscar CEP", 'value="Rua Padre Fernando Pedreira de Castro"')

      patch "/contract/billing-address", params: { billing_account: { street_number: "" } }
      expect(response).to have_http_status(:unprocessable_content)
      patch "/contract/billing-address", params: { billing_account: { street_number: "32" } }
      expect(response).to redirect_to("/invoices")
      expect(subscription.billing_account.reload.street_number).to eq("32")
    end

    it "keeps the billing address closed to the HR analyst (D-635)" do
      sign_in_member(company, brand, %w[hr_analyst])

      get "/contract/billing-address/edit"
      expect(response).to have_http_status(:forbidden)
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

    it "asks for the billing address before the first payment, and keeps it (D-635)" do
      subscription.billing_account.update_columns(postal_code: nil, street: nil, street_number: nil, district: nil, city: nil, state: nil)
      sign_in_member(partner, brand, %w[partner_admin])

      get "/partner/contract/new"
      expect(response.body).to include("Endereço de cobrança", "Buscar CEP")

      post "/partner/contract", params: { plan_id: subscription.plan.id, modules: %w[ponto], billing_account: { postal_code: "123" } }
      expect(response).to have_http_status(:unprocessable_content)
      expect(Invoice.where(checkout: true)).to be_empty

      post "/partner/contract", params: { plan_id: subscription.plan.id, modules: %w[ponto],
        billing_account: BillingHelpers::BILLING_ADDRESS.merge(postal_code: "04696-180") }
      expect(response).to redirect_to("/partner/invoices/#{Invoice.find_by!(checkout: true).id}")
      expect(subscription.billing_account.reload).to be_billing_address_complete
    end

    it "lets the administrator change the billing address, with the address by CEP, and not the consultant (D-635)" do
      allow(Addresses::PostalCodeLookup).to receive(:call).and_return(Addresses::PostalCodeLookup::Result.new(postal_code: "01310100",
        street: "Avenida Paulista", district: "Bela Vista", city: "São Paulo", state: "SP", ibge_city_code: "3550308"))
      sign_in_member(partner, brand, %w[partner_admin])

      get "/partner/invoices"
      expect(response.body).to include("Endereço de cobrança", "Rua Padre Fernando Pedreira de Castro, 30 - Jurubatuba", "Alterar")
      get "/partner/address-lookup/01310100"
      expect(response.parsed_body).to include("street" => "Avenida Paulista")

      patch "/partner/contract/billing-address", params: { billing_account: { street: "Avenida Paulista", street_number: "1000",
        district: "Bela Vista", postal_code: "01310-100" } }
      expect(response).to redirect_to("/partner/invoices")
      expect(subscription.billing_account.reload.billing_address_line).to start_with("Avenida Paulista, 1000 - Bela Vista")
    end

    it "keeps the billing address closed to the consultant (D-635)" do
      sign_in_member(partner, brand, %w[consultant])

      get "/partner/contract/billing-address/edit"
      expect(response).to have_http_status(:forbidden)
    end
  end
end
