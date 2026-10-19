require "rails_helper"

# Spec 19, block 19b-1 (D-612, D-613): partners and direct companies registered by the
# CatalystHR team with their contracts (RN-19-001, RN-19-002, RN-19-035, RN-19-081).
RSpec.describe "Clients and contracts", type: :request do
  include ActiveJob::TestHelper

  before do
    travel_to Time.zone.local(2026, 10, 19, 10)
    Flipper.enable(FeatureFlags::SIGN_IN)
    Flipper.enable(FeatureFlags::BILLING)
    host! "admin.catalysthr.com.br"
  end

  def sign_in(role)
    user = enable_mfa(create(:user, platform_role: role, cpf: "52998224725", name: "Paulo Lima"))
    sign_in_with_mfa("52998224725", user)
    user
  end

  let!(:partner_plan) { create(:plan_version, plan: create(:plan, name: "Até 500 colaboradores")).plan }
  let!(:direct_plan) { create(:plan_version, plan: create(:plan, :direct, name: "Empresa direta")).plan }

  def client_params(**overrides)
    {
      kind: "partner", mode: "trial", legal_name: "Aurora Gestão de Pessoas Ltda", commercial_name: "Aurora RH",
      cnpj: "11.222.333/0001-81", slug: "aurora", plan_id: partner_plan.id, modules: [ "ponto" ],
      admin_name: "Ana Prado", admin_cpf: "111.444.777-35", admin_email: "ana@aurora.example"
    }.merge(overrides)
  end

  it "registers a partner in a 14-day trial, with brand, address, contract and the administrator's invitation (RN-19-081, RN-19-030)" do
    finance = sign_in("finance")

    get "/clients/new", params: { kind: "partner" }
    expect(response).to have_http_status(:ok)

    expect {
      post "/clients", params: { client: client_params }
    }.to have_enqueued_job(Invitations::DeliverJob)

    account = BillingAccount.sole
    expect(response).to redirect_to("/clients/#{account.id}")
    partner = account.owner
    expect(partner).to have_attributes(class: Partner, name: "Aurora RH", legal_name: "Aurora Gestão de Pessoas Ltda", cnpj: "11222333000181")
    expect(partner.brand.active_subdomain.slug).to eq("aurora")
    expect(account).to have_attributes(cycle_day: 19, responsible_user: User.find_by!(email: "ana@aurora.example"))

    subscription = account.subscription
    expect(subscription).to have_attributes(status: "trialing", started_on: Date.new(2026, 10, 19), trial_ends_on: Date.new(2026, 11, 2),
      plan_version: partner_plan.version_on, pre_activation_price: nil, activated_on: nil, created_by: finance)
    expect(subscription.modules).to eq([ "ponto" ])

    membership = Membership.find_by!(organization: partner)
    expect(membership).to have_attributes(roles: [ "partner_admin" ], status: "invited")

    get "/clients/#{account.id}"
    expect(response.body).to include("Aurora RH", "aurora.painel.catalysthr.com.br", "Em teste", "02/11/2026", "Ana Prado")
  end

  it "registers a direct company under contract, with the CNPJ root and the headquarters (RN-04-001, D-600)" do
    sign_in("superadmin")

    post "/clients", params: { client: client_params(kind: "direct", mode: "contract", legal_name: "Metalúrgica Serra Azul Ltda",
      commercial_name: "Serra Azul", slug: "serra-azul", plan_id: direct_plan.id, modules: %w[ponto folha]) }

    company = Company.find_by!(document: "11222333")
    expect(company).to have_attributes(name: "Serra Azul", partner_id: nil, employer_type: "company")
    expect(company.headquarters.registration_number).to eq("11222333000181")
    expect(company.billing_account.subscription).to have_attributes(status: "active", activated_on: Date.new(2026, 10, 19))
    expect(company.billing_account.subscription.modules).to contain_exactly("ponto", "folha")
    expect(Membership.find_by!(organization: company).roles).to eq([ "hr_admin" ])
  end

  it "starts a partner's contract on the pre-activation fee in force, kept in the subscription (RN-19-035, D-612)" do
    sign_in("finance")

    post "/clients", params: { client: client_params(mode: "contract") }
    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("cadastre antes a mensalidade de pré-ativação")
    expect(Partner.count).to eq(0)

    price = create(:pre_activation_price, monthly_price_cents: 1_990)
    post "/clients", params: { client: client_params(mode: "contract") }

    subscription = BillingAccount.sole.subscription
    expect(subscription).to have_attributes(status: "active", pre_activation_price: price, activated_on: nil)
    expect(subscription).to be_pre_activation

    get "/clients/#{subscription.billing_account_id}"
    expect(response.body).to include("Pré-ativação", "R$ 19,90 por mês até o primeiro colaborador ativo na carteira")
  end

  it "invites the person who already has the CPF, without changing their data nor showing their e-mail (D-209)" do
    sign_in("finance")
    create(:user, cpf: "11144477735", name: "Ana Prado Souza", email: "ana.antiga@example.com")

    post "/clients", params: { client: client_params }
    follow_redirect!

    expect(response.body).to include("já tinha conta na plataforma")
    expect(response.body).not_to include("ana.antiga@example.com")
    expect(BillingAccount.sole.responsible_user).to have_attributes(name: "Ana Prado Souza", email: "ana.antiga@example.com")
  end

  it "takes day 28 as the cycle of contracts started on days 29 to 31 (RN-19-040, P-19-11)" do
    travel_to Time.zone.local(2026, 10, 31, 10)
    sign_in("finance")

    post "/clients", params: { client: client_params }

    expect(BillingAccount.sole.cycle_day).to eq(28)
  end

  it "keeps the add-on with the price version sold (D-611)" do
    sign_in("finance")
    price = create(:add_on_price, monthly_price_cents: 9_900)

    post "/clients", params: { client: client_params(add_on_codes: [ "whatsapp_sender" ]) }

    expect(BillingAccount.sole.subscription.add_on_prices).to eq([ price ])
  end

  it "creates nothing when part of the registration is refused" do
    sign_in("finance")
    create(:brand, owner: create(:partner)).subdomains.create!(slug: "aurora")

    post "/clients", params: { client: client_params(admin_cpf: "123") }
    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("CPF do administrador")

    post "/clients", params: { client: client_params(cnpj: "11.222.333/0001-81") }
    expect(response).to have_http_status(:unprocessable_content)
    expect([ Partner.where(cnpj: "11222333000181").count, BillingAccount.count, Membership.count ]).to eq([ 0, 0, 0 ])
  end

  it "refuses a plan of the other kind or not on sale" do
    sign_in("finance")
    archived = create(:plan_version, plan: create(:plan, status: "archived")).plan

    post "/clients", params: { client: client_params(plan_id: direct_plan.id) }
    expect(response).to have_http_status(:unprocessable_content)
    post "/clients", params: { client: client_params(plan_id: archived.id) }
    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("precisa ser um plano ativo deste tipo")
    expect(BillingAccount.count).to eq(0)
  end

  it "lets the support read the clients but not register them (spec 19, section 6)" do
    sign_in("support")

    get "/clients"
    expect(response).to have_http_status(:ok)
    expect(response.body).not_to include("Novo parceiro")

    post "/clients", params: { client: client_params }
    expect(response).to have_http_status(:forbidden)
    expect(Partner.count).to eq(0)
  end

  it "registers the pre-activation fee with versions (RN-19-035, D-611)" do
    sign_in("finance")

    post "/pre-activation-prices", params: { pre_activation_price: { monthly_price: "19,90", valid_from: "2026-10-19" } }
    expect(response).to redirect_to("/plans")
    post "/pre-activation-prices", params: { pre_activation_price: { monthly_price: "24,90", valid_from: "2026-12-01" } }

    expect(PreActivationPrice.order(:version).pluck(:version, :monthly_price_cents)).to eq([ [ 1, 1_990 ], [ 2, 2_490 ] ])
    expect(PreActivationPrice.on.monthly_price_cents).to eq(1_990)
    expect(PreActivationPrice.on(Date.new(2026, 12, 1)).monthly_price_cents).to eq(2_490)

    get "/plans"
    expect(response.body).to include("R$ 19,90", "Próximo preço: R$ 24,90 a partir de 01/12/2026")
  end

  it "hides the clients while billing is off (D-610)" do
    Flipper.disable(FeatureFlags::BILLING)
    sign_in("superadmin")

    get "/clients"

    expect(response).to have_http_status(:not_found)
  end
end
