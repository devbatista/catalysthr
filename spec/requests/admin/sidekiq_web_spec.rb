require "rails_helper"

# Spec 20, block 20b (RN-20-077, D-627): Sidekiq Web in the admin area, only for the
# superadmin and the support, signed in with MFA.
RSpec.describe "Sidekiq Web", type: :request do
  before do
    Flipper.enable(FeatureFlags::SIGN_IN)
    host! "admin.catalysthr.com.br"
  end

  def sign_in(role)
    user = enable_mfa(create(:user, platform_role: role, cpf: "52998224725"))
    sign_in_with_mfa("52998224725", user)
    user
  end

  %w[superadmin support].each do |role|
    it "opens for the #{role}, with the item in the menu" do
      sign_in(role)

      get "/"
      expect(response.body).to include("Filas de jobs", 'href="/sidekiq"')

      get "/sidekiq"
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Sidekiq")
    end
  end

  it "does not exist for the finance team" do
    sign_in("finance")

    get "/sidekiq"
    expect(response).to have_http_status(:not_found)

    get "/"
    expect(response.body).not_to include("Filas de jobs")
  end

  it "asks the sign-in without a session" do
    get "/sidekiq"

    expect(response).to redirect_to("http://admin.catalysthr.com.br/sign-in")
  end

  it "does not exist on a brand's panel" do
    brand = create(:brand_subdomain, slug: "aurora").brand
    host! "aurora.painel.catalysthr.com.br"
    expect(brand).to be_persisted

    get "/sidekiq"
    expect(response).to have_http_status(:not_found)
  end
end
