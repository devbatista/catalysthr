require "rails_helper"

# Spec 19, block 19g (RN-19-090, P-19-28, D-610, D-626): the CatalystHR team's panel, with
# Revenue for the superadmin and the finance team and Clients also for the support.
RSpec.describe "Team panel", type: :request do
  before do
    travel_to Time.zone.local(2026, 10, 22, 10)
    Flipper.enable(FeatureFlags::SIGN_IN)
    Flipper.enable(FeatureFlags::BILLING)
    host! "admin.catalysthr.com.br"
  end

  def sign_in(role)
    user = enable_mfa(create(:user, platform_role: role, cpf: "52998224725", name: "Paulo Lima"))
    sign_in_with_mfa("52998224725", user)
    user
  end

  let!(:subscription) { contract_for(create(:partner, name: "Aurora Gestão de Pessoas")) }

  it "shows Revenue and Clients to the finance team, with the item in the menu" do
    sign_in("finance")

    get "/dashboard"
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Painel da equipe CatalystHR", "Receita recorrente mensal", "R$ 2.500,00", "Conversão de testes",
      "Aurora Gestão de Pessoas", "Último acesso", "Indicadores")
  end

  it "shows only Clients to the support (P-19-28)" do
    sign_in("support")

    get "/dashboard"
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Aurora Gestão de Pessoas", "Risco")
    expect(response.body).not_to include("Receita recorrente mensal", "R$ 2.500,00")
  end

  it "answers 404 while billing is off (D-610)" do
    Flipper.disable(FeatureFlags::BILLING)
    sign_in("superadmin")

    get "/dashboard"
    expect(response).to have_http_status(:not_found)
  end
end
