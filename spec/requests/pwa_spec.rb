require "rails_helper"

# Spec 16, block 16b (RN-16-060 to RN-16-083, D-424, D-646): the manifest, the service
# worker with only the app's shell, the page without connection, the update and old
# browser notices, the install invite and the text on the brand's primary color.
RSpec.describe "PWA", type: :request do
  let(:company) { create(:company, name: "Metalúrgica Serra Azul") }
  let(:brand) { create(:brand, owner: company, commercial_name: "Serra Azul RH") }

  before do
    brand.subdomains.create!(slug: "serraazul")
    Flipper.enable(FeatureFlags::SIGN_IN)
    host! "serraazul.painel.catalysthr.com.br"
  end

  it "opens the installed app at \"/\", which sends each person by profile (RN-16-060, D-646)" do
    get "/manifest.webmanifest"

    expect(JSON.parse(response.body)).to include("id" => "/", "start_url" => "/", "scope" => "/", "display" => "standalone",
      "name" => "Serra Azul RH")
  end

  it "serves the worker before anyone signs in, keeping only the shell and the page without connection (RN-16-061, D-424)" do
    get "/service-worker.js"

    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("text/javascript")
    expect(response.headers["Cache-Control"]).to include("no-cache")
    expect(response.body).to include('const OFFLINE = "/offline"', 'const CACHE = "shell-', 'url.pathname.startsWith("/assets/")',
      'request.mode === "navigate"')
  end

  it "changes the worker's version when the worker changes (RN-16-064)" do
    get "/service-worker.js"
    first = response.body[/shell-(\w+)/, 1]
    stub_const("Panel::ServiceWorkersController::WORKER_REVISION", Panel::ServiceWorkersController::WORKER_REVISION + 1)
    get "/service-worker.js"

    expect(response.body[/shell-(\w+)/, 1]).not_to eq(first)
  end

  it "shows \"Sem conexão\" with the brand and nothing of the person (RN-16-062, CA-16-007, CA-16-008)" do
    get "/offline"

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Sem conexão", "Serra Azul RH", "Nada do que você estava fazendo foi guardado", "/assets/")
    expect(response.body).not_to include("csrf-token", "data-bell")
  end

  describe "for a signed-in employee" do
    let!(:hr_user) { create(:user, name: "Juliana Ribeiro") }
    let!(:hr) { create(:membership, user: hr_user, organization: company, roles: %w[hr_admin]) }
    let(:profile) { register_employee(company, by: hr_user, position: create_position(company), name: "Rafael Moura Campos") }

    before do
      publish_platform_legal_documents
      user = profile.user
      user.update!(password: "Catalyst#2026", password_confirmation: "Catalyst#2026")
      ActsAsTenant.with_tenant(company) { profile.membership.update!(status: "active") }
      accept_legal_documents(user, brand)
      post "/sign-in", params: { user: { login: user.cpf, password: "Catalyst#2026" } }
    end

    it "has the install invite with the iPhone's steps, and the update and old browser notices (RN-16-065, RN-16-080, CA-16-006)" do
      get "/portal"

      expect(response.body).to include("data-install-invite", "Instale o app", "Toque em Compartilhar", "Adicionar à Tela de Início",
        "Agora não", "data-sw-update", "Nova versão disponível", "data-old-browser", "Seu navegador está desatualizado")
    end

    it "refuses a light yellow primary color, and writes dark text on one already stored (RN-01-031, RN-16-083, CA-16-012, D-646)" do
      expect(brand.update(primary_color: "#F7E27A")).to be(false)
      brand.reload.update_column(:primary_color, "#F7E27A")
      get "/portal"
      expect(response.body).to include("--brand-on-primary: #0C1E33;")

      brand.update!(primary_color: "#085087")
      get "/portal"
      expect(response.body).to include("--brand-on-primary: #FFFFFF;")
    end
  end
end
