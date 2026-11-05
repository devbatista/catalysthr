require "rails_helper"

# RN-02-032 (P-02-15): limits per address on sign-in, recovery and unlock.
RSpec.describe "Request limits", type: :request do
  let(:cache) { ActiveSupport::Cache::MemoryStore.new }

  before do
    Rack::Attack.cache.store = cache
    brand = create(:brand)
    brand.subdomains.create!(slug: "aurora")
    Flipper.enable(FeatureFlags::SIGN_IN)
    host! "aurora.painel.catalysthr.com.br"
  end

  after { Rack::Attack.cache.store = Rails.cache }

  it "stops sign-in attempts from the same address after 30 in a minute" do
    # The limit counts per minute: the clock stands still so the attempts never cross into the next one.
    freeze_time do
      30.times do |n|
        post "/sign-in", params: { user: { login: format("%011d", n), password: "Errada#2026" } }
        expect(response).not_to have_http_status(:too_many_requests)
      end

      post "/sign-in", params: { user: { login: "12345678909", password: "Errada#2026" } }
      expect(response).to have_http_status(:too_many_requests)
      expect(response.body).to eq("Muitas tentativas a partir deste endereço. Aguarde alguns minutos e tente de novo.")
    end

    travel 1.minute do
      post "/sign-in", params: { user: { login: "12345678909", password: "Errada#2026" } }
      expect(response).not_to have_http_status(:too_many_requests)
    end
  end

  it "stops recovery requests for the same CPF from any address after 5" do
    freeze_time do
      5.times do |n|
        post "/password", params: { user: { login: "123.456.789-09" } }, env: { "REMOTE_ADDR" => "10.0.0.#{n + 1}" }
        expect(response).not_to have_http_status(:too_many_requests)
      end

      post "/unlock", params: { user: { login: "12345678909" } }, env: { "REMOTE_ADDR" => "10.0.0.9" }
      expect(response).to have_http_status(:too_many_requests)
    end
  end

  it "keeps no CPF in the cache keys" do
    post "/password", params: { user: { login: "123.456.789-09" } }

    expect(cache.instance_variable_get(:@data).keys.join).not_to include("12345678909")
  end

  it "counts passkey sign-ins with the password's attempts (RN-16-071)" do
    Flipper.enable(FeatureFlags::PASSKEYS)
    freeze_time do
      30.times { post "/sign-in/passkey", as: :json }
      expect(response).not_to have_http_status(:too_many_requests)

      post "/sign-in", params: { user: { login: "12345678909", password: "Errada#2026" } }
      expect(response).to have_http_status(:too_many_requests)
    end
  end

  it "leaves room for the challenge every sign-in page asks, up to 60 a minute" do
    Flipper.enable(FeatureFlags::PASSKEYS)
    freeze_time do
      60.times { post "/sign-in/passkey/challenge", as: :json }
      expect(response).not_to have_http_status(:too_many_requests)

      post "/sign-in/passkey/challenge", as: :json
      expect(response).to have_http_status(:too_many_requests)
    end
  end

  it "stops passkey confirmations and registering passwords with the password's limit (RN-16-070, RN-16-073)" do
    freeze_time do
      10.times { post "/confirm-password/passkey", as: :json }
      post "/security/passkeys/challenge", as: :json
      expect(response).to have_http_status(:too_many_requests)
    end
  end
end
