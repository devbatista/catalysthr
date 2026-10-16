require "rails_helper"

# Spec 01, RN-01-001: every request is resolved by its host.
RSpec.describe "Host resolution", type: :request do
  let(:brand) do
    create(:brand, commercial_name: "Aurora RH", primary_color: "#6B2FA3",
      login_welcome_text: "Bem-vindo ao portal de RH da Aurora.")
  end

  before { brand.subdomains.create!(slug: "aurora") }

  it "opens the brand's page with its name, colors and welcome text (CA-01-001)" do
    host! "aurora.painel.catalysthr.com.br"
    get "/"

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Aurora RH", "Bem-vindo ao portal de RH da Aurora.", "--brand-primary: #6B2FA3")
    expect(response.body).to include('lang="pt-BR"')
  end

  it "shows the commercial name as text when the brand has no logo (P-01-02)" do
    host! "aurora.painel.catalysthr.com.br"
    get "/"

    expect(response.body).to include('<p class="text-center text-2xl font-bold text-brand-primary">Aurora RH</p>')
  end

  it "opens the admin area at the admin host (D-156)" do
    host! "admin.catalysthr.com.br"
    get "/"

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Área administrativa em construção.")
  end

  it "answers a neutral 404 for an unknown slug, a nested host or another domain" do
    [ "naoexiste.painel.catalysthr.com.br", "a.aurora.painel.catalysthr.com.br", "catalysthr.com.br", "evil.example" ].each do |host|
      host! host
      get "/"

      expect(response).to have_http_status(:not_found), host
      expect(response.body).to include("Página não encontrada")
      expect(response.body).not_to include("Aurora")
    end
  end

  it "answers the health check on any host (D-573)" do
    host! "health.painel.catalysthr.com.br"
    get "/up"

    expect(response).to have_http_status(:ok)
  end

  describe "slug change (D-157)" do
    before { Brands::ChangeSlug.call(brand: brand, slug: "auroragp") }

    it "redirects the old slug with 301 to the same path on the new one (CA-01-006)" do
      travel 10.days do
        host! "aurora.painel.catalysthr.com.br"
        get "/colaboradores?pagina=2"

        expect(response).to have_http_status(:moved_permanently)
        expect(response.location).to eq("http://auroragp.painel.catalysthr.com.br/colaboradores?pagina=2")
        # The change and the request may fall a second apart.
        max_age = response.headers["cache-control"][/\Apublic, max-age=(\d+)\z/, 1].to_i
        expect(max_age).to be_between(80.days.to_i - 1, 80.days.to_i)
      end
    end

    it "answers 404 once the 90 days are over, even before the release job (CA-01-007)" do
      travel 91.days do
        host! "aurora.painel.catalysthr.com.br"
        get "/colaboradores"

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  it "serves the brand's PWA manifest (RN-01-033, CA-01-011)" do
    brand.update!(short_name: "Aurora")
    host! "aurora.painel.catalysthr.com.br"
    get "/manifest.webmanifest"

    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("application/manifest+json")
    expect(JSON.parse(response.body)).to include("name" => "Aurora RH", "short_name" => "Aurora",
      "theme_color" => "#6B2FA3", "display" => "standalone")
  end

  it "keeps the brand identification cached and expires it when the subdomain changes (P-01-16)" do
    cache = ActiveSupport::Cache::MemoryStore.new
    allow(Rails).to receive(:cache).and_return(cache)

    expect(Brands::HostLookup.call("aurora")).to be_active
    expect(cache.exist?(Brands::HostLookup.cache_key("aurora"))).to be(true)

    Brands::ChangeSlug.call(brand: brand, slug: "auroragp")

    expect(Brands::HostLookup.call("aurora")).to be_redirecting
  end
end
