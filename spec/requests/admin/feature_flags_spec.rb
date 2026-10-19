require "rails_helper"

# RN-20-030, D-617: the feature flags on the admin's screen, for the superadmin only.
RSpec.describe "Feature flags", type: :request do
  before do
    Flipper.enable(FeatureFlags::SIGN_IN)
    host! "admin.catalysthr.com.br"
  end

  def sign_in(role)
    user = enable_mfa(create(:user, platform_role: role, cpf: "52998224725", name: "Paulo Lima"))
    sign_in_with_mfa("52998224725", user)
    user
  end

  it "lists the flags of the code with their state, and turns one on and off for everyone, recording who did it" do
    superadmin = sign_in("superadmin")

    get "/feature-flags"
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Flags", "Acesso ao sistema", "Cobrança", "billing", "Ligada", "Desligada")
    expect(response.body).to include('href="/feature-flags"')

    patch "/feature-flags/billing", params: { state: "on" }
    expect(response).to redirect_to("/feature-flags")
    expect(flash[:notice]).to eq("Flag \"Cobrança\" ligada para todos.")
    expect(Flipper.enabled?(FeatureFlags::BILLING)).to be(true)

    patch "/feature-flags/billing", params: { state: "off" }
    expect(Flipper.enabled?(FeatureFlags::BILLING)).to be(false)
    expect(FeatureFlagChange.order(:created_at).pluck(:flag, :action, :changed_by_id)).to eq(
      [ [ "billing", "enabled", superadmin.id ], [ "billing", "disabled", superadmin.id ] ])

    get "/feature-flags"
    expect(response.body).to include("Desligada por Paulo Lima")
  end

  it "never turns sign-in off, which would close every page, this one included" do
    sign_in("superadmin")

    get "/feature-flags"
    expect(response.body).to include("Desliga só pelo console")
    expect(response.body).not_to include('action="/feature-flags/sign_in"')

    patch "/feature-flags/sign_in", params: { state: "off" }
    expect(response).to have_http_status(:not_found)
    expect(Flipper.enabled?(FeatureFlags::SIGN_IN)).to be(true)
    expect { FeatureFlags.switch!(FeatureFlags::SIGN_IN, on: false, by: create(:user)) }.to raise_error(ArgumentError)
  end

  it "does not touch a flag the code does not declare" do
    sign_in("superadmin")

    patch "/feature-flags/anything", params: { state: "on" }

    expect(response).to have_http_status(:not_found)
    expect(FeatureFlagChange.count).to eq(0)
  end

  it "creates the declared flags the database lacks, disabled" do
    superadmin = sign_in("superadmin")
    Flipper.remove(FeatureFlags::COMPANY_TRANSFER)

    # Production does not raise for a missing flag; strict mode does, in tests.
    Flipper::Adapters::Strict.with_sync_mode do
      get "/feature-flags"
      expect(response.body).to include("ainda não estão no banco: Transferência de empresa", "Fora do banco")

      post "/feature-flags/declare"
    end
    expect(flash[:notice]).to eq("1 flag criada, desligada.")
    expect(FeatureFlags.state(FeatureFlags::COMPANY_TRANSFER)).to eq(:off)
    expect(FeatureFlagChange.sole).to have_attributes(flag: "company_transfer", action: "declared", changed_by: superadmin)
  end

  it "removes a flag the code no longer declares, but never a declared one" do
    sign_in("superadmin")
    Flipper::Adapters::Strict.with_sync_mode { Flipper.add(:old_feature) }

    get "/feature-flags"
    expect(response.body).to include("Flags que o código não usa mais", "old_feature")

    delete "/feature-flags/old_feature"
    expect(FeatureFlags.stored).not_to include(:old_feature)
    expect(FeatureFlagChange.sole).to have_attributes(flag: "old_feature", action: "removed")

    delete "/feature-flags/sign_in"
    expect(response).to have_http_status(:not_found)
    expect(FeatureFlags.stored).to include(:sign_in)
  end

  it "shows a flag on for some only, and turning it off clears it" do
    sign_in("superadmin")
    Flipper.enable_actor(FeatureFlags::BILLING, create(:company))

    get "/feature-flags"
    expect(response.body).to include("Ligada para alguns")

    patch "/feature-flags/billing", params: { state: "off" }
    expect(FeatureFlags.state(FeatureFlags::BILLING)).to eq(:off)
  end

  %w[finance support].each do |role|
    it "keeps the screen closed to the #{role} team" do
      sign_in(role)

      get "/feature-flags"
      expect(response).to have_http_status(:forbidden)
      patch "/feature-flags/billing", params: { state: "on" }
      expect(response).to have_http_status(:forbidden)
      expect(Flipper.enabled?(FeatureFlags::BILLING)).to be(false)

      get "/"
      expect(response.body).not_to include('href="/feature-flags"')
    end
  end

  it "has a name and a description for every declared flag" do
    FeatureFlags::ALL.each do |name|
      expect(I18n.t("feature_flags.#{name}", default: nil)).to include(:name, :description)
    end
  end
end
