require "rails_helper"

# Spec 19, block 19a (D-610, D-611): plans, modules and add-ons with price versions, by the
# superadmin and the finance team (spec 03, section 4.1).
RSpec.describe "Plans and prices", type: :request do
  before do
    Flipper.enable(FeatureFlags::SIGN_IN)
    Flipper.enable(FeatureFlags::BILLING)
    host! "admin.catalysthr.com.br"
  end

  def sign_in(role)
    user = enable_mfa(create(:user, platform_role: role, cpf: "52998224725", name: "Paulo Lima"))
    sign_in_with_mfa("52998224725", user)
    user
  end

  let(:partner_version) do
    {
      monthly_price: "1.500,00", employee_limit: "500", overage_per_employee: "3,00",
      ai_credits: "1000", whatsapp_messages: "2000", ai_credit_overage: "0,50", whatsapp_overage: "0,35",
      module_prices: { ponto: "400,00", folha: "600,00" }, valid_from: Date.current.iso8601
    }
  end

  it "lets the finance team create a partner plan with its first version (RN-19-010, D-480)" do
    finance = sign_in("finance")

    get "/plans/new", params: { kind: "partner" }
    expect(response).to have_http_status(:ok)

    post "/plans", params: { plan: { kind: "partner", name: "Até 500 colaboradores" }, plan_version: partner_version }

    plan = Plan.last
    expect(response).to redirect_to("/plans/#{plan.id}")
    version = plan.plan_versions.sole
    expect(version).to have_attributes(version: 1, monthly_price_cents: 150_000, employee_limit: 500, overage_per_employee_cents: 300,
      ai_credits: 1_000, whatsapp_messages: 2_000, ai_credit_overage_cents: 50, whatsapp_overage_cents: 35, created_by: finance)
    expect(version.plan_modules.pluck(:module, :price_cents)).to contain_exactly([ "ponto", 40_000 ], [ "folha", 60_000 ])

    get "/plans/#{plan.id}"
    expect(response.body).to include("Até 500 colaboradores", "R$ 1.500,00 por mês, até 500 colaboradores", "Vigente", "Paulo Lima")
  end

  it "lets the superadmin create a direct company plan, with prices per employee (D-122)" do
    sign_in("superadmin")

    post "/plans", params: {
      plan: { kind: "direct", name: "Empresa direta" },
      plan_version: {
        price_per_employee: "12,00", minimum_monthly: "300,00", ai_credits_per_employee: "3", whatsapp_messages_per_employee: "5",
        ai_credit_overage: "0,50", whatsapp_overage: "0,35", module_prices: { ponto: "4,00", folha: "6,00" },
        valid_from: Date.current.iso8601,
        # A partner field sent by hand never reaches a direct plan.
        monthly_price: "9.999,00"
      }
    }

    version = Plan.last.plan_versions.sole
    expect(version).to have_attributes(price_per_employee_cents: 1_200, minimum_monthly_cents: 30_000, ai_credits_per_employee: 3,
      whatsapp_messages_per_employee: 5, monthly_price_cents: nil)

    get "/plans"
    expect(response.body).to include("Empresa direta", "R$ 12,00 por colaborador, mínimo de R$ 300,00")
  end

  it "saves neither the plan nor the version when the version is wrong" do
    sign_in("finance")

    post "/plans", params: { plan: { kind: "partner", name: "Até 500" },
      plan_version: partner_version.merge(monthly_price: "mil reais", valid_from: Date.yesterday.iso8601) }

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("precisa ser um valor em reais", "não pode ser uma data passada")
    expect(Plan.count).to eq(0)
    expect(PlanVersion.count).to eq(0)
  end

  it "registers a new price as a new version and keeps the old one (RN-19-014, D-611)" do
    sign_in("finance")
    plan = create(:plan, name: "Até 500")
    create(:plan_version, plan: plan, monthly_price_cents: 150_000)

    get "/plans/#{plan.id}/versions/new"
    expect(response.body).to include("1.500,00")

    next_month = 1.month.from_now.to_date
    post "/plans/#{plan.id}/versions", params: { plan_version: partner_version.merge(monthly_price: "1.700,00", valid_from: next_month.iso8601) }
    expect(response).to redirect_to("/plans/#{plan.id}")

    # A typo in the future version is corrected by another of the same date.
    post "/plans/#{plan.id}/versions", params: { plan_version: partner_version.merge(monthly_price: "1.650,00", valid_from: next_month.iso8601) }

    plan.reload
    expect(plan.plan_versions.pluck(:version, :monthly_price_cents)).to eq([ [ 1, 150_000 ], [ 2, 170_000 ], [ 3, 165_000 ] ])
    expect(plan.version_on.monthly_price_cents).to eq(150_000)
    expect(plan.version_on(next_month).monthly_price_cents).to eq(165_000)

    get "/plans/#{plan.id}"
    expect(response.body).to include("Vigente", "Futura", "Substituída")
  end

  it "edits only the name and the status of a plan" do
    sign_in("finance")
    plan = create(:plan, name: "Até 500")
    create(:plan_version, plan: plan)

    patch "/plans/#{plan.id}", params: { plan: { name: "Faixa 500", status: "archived", kind: "direct" } }

    expect(response).to redirect_to("/plans/#{plan.id}")
    expect(plan.reload).to have_attributes(name: "Faixa 500", status: "archived", kind: "partner")
  end

  it "registers the add-on's price, creating the add-on with its first price (RN-19-013, D-611)" do
    finance = sign_in("finance")

    get "/add-ons/whatsapp_sender/prices/new"
    expect(response).to have_http_status(:ok)
    expect(AddOn.count).to eq(0)

    post "/add-ons/whatsapp_sender/prices", params: { add_on_price: { monthly_price: "99,00", valid_from: Date.current.iso8601 } }
    expect(response).to redirect_to("/plans")

    price = AddOn.find_by!(code: "whatsapp_sender").prices.sole
    expect(price).to have_attributes(version: 1, monthly_price_cents: 9_900, created_by: finance)

    get "/plans"
    expect(response.body).to include("Número próprio de WhatsApp", "R$ 99,00")
  end

  it "answers 404 for an add-on that does not exist" do
    sign_in("finance")

    post "/add-ons/face_recognition/prices", params: { add_on_price: { monthly_price: "10,00", valid_from: Date.current.iso8601 } }

    expect(response).to have_http_status(:not_found)
    expect(AddOn.count).to eq(0)
  end

  it "shows the menu item to the finance team" do
    sign_in("finance")

    get "/"

    expect(response.body).to include("Cobrança", "Planos e preços")
  end

  it "does not let the support see or change plans (403, spec 03, section 4.1)" do
    sign_in("support")
    plan = create(:plan)

    get "/plans"
    expect(response).to have_http_status(:forbidden)
    post "/plans", params: { plan: { kind: "partner", name: "Outro" }, plan_version: partner_version }
    expect(response).to have_http_status(:forbidden)
    post "/plans/#{plan.id}/versions", params: { plan_version: partner_version }
    expect(response).to have_http_status(:forbidden)
    post "/add-ons/whatsapp_sender/prices", params: { add_on_price: { monthly_price: "99,00", valid_from: Date.current.iso8601 } }
    expect(response).to have_http_status(:forbidden)

    get "/"
    expect(response.body).not_to include("Planos e preços")
    expect(Plan.count).to eq(1)
  end

  it "hides the screens while billing is off (D-610)" do
    Flipper.disable(FeatureFlags::BILLING)
    sign_in("superadmin")

    get "/plans"
    expect(response).to have_http_status(:not_found)

    get "/"
    expect(response.body).not_to include("Planos e preços")
  end
end
