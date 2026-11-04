require "rails_helper"

# Spec 02, RN-02-014 (item 2), RN-02-015 and RN-02-017; D-577 and D-578.
RSpec.describe "Terms and privacy policy", type: :request do
  let(:partner) { create(:partner) }
  let(:brand) { create(:brand, owner: partner) }
  let(:company) { create(:company, partner: partner) }
  let!(:user) { create(:user, cpf: "12345678909") }
  let!(:author) { create(:user, platform_role: "superadmin") }

  before do
    create(:membership, user: user, organization: company, roles: %w[manager])
    brand.subdomains.create!(slug: "aurora")
    Flipper.enable(FeatureFlags::SIGN_IN)
    host! "aurora.painel.catalysthr.com.br"
  end

  def publish(kind, body, brand: nil)
    create(:legal_document, kind: kind, body: body, brand: brand, published_by: author)
  end

  def sign_in
    post "/sign-in", params: { user: { login: "12345678909", password: "Catalyst#2026" } }
  end

  def accept_all
    post "/first-access/terms", params: { accept: { terms: "1", privacy: "1" } },
      headers: { "User-Agent" => "Navegador de teste" }
  end

  it "asks for the CatalystHR texts when the brand has none, and records each acceptance (RN-02-015)" do
    publish("terms", "Termos da CatalystHR")
    privacy = publish("privacy", "Política da CatalystHR")
    sign_in

    get "/"
    expect(response).to redirect_to("/first-access/terms")

    get "/first-access/terms"
    expect(response.body).to include("Termos da CatalystHR", "Política da CatalystHR")

    accept_all
    expect(response).to redirect_to("/")

    consent = user.consents.find_by!(kind: "privacy")
    expect(consent).to have_attributes(legal_document: privacy, document_version: 1, granted: true, scope: brand,
      ip: "127.0.0.1", user_agent: "Navegador de teste")
    expect(consent.decided_at).to be_present

    # A manager starts at the portal (spec 16, RN-16-002).
    get "/"
    expect(response).to redirect_to("/portal")
  end

  it "uses the brand's own texts when it has them (RN-01-032)" do
    publish("terms", "Termos da CatalystHR")
    publish("privacy", "Política da CatalystHR")
    publish("terms", "Termos da Aurora", brand: brand)
    sign_in

    get "/first-access/terms"

    expect(response.body).to include("Termos da Aurora", "Política da CatalystHR")
    expect(response.body).not_to include("Termos da CatalystHR")
  end

  it "asks again only for the text with a new version (RN-02-017)" do
    publish("terms", "Termos versão 1")
    publish("privacy", "Política versão 1")
    sign_in
    accept_all

    publish("terms", "Termos versão 2")
    get "/"
    expect(response).to redirect_to("/first-access/terms")

    get "/first-access/terms"
    expect(response.body).to include("Termos versão 2")
    expect(response.body).not_to include("Política versão 1")
  end

  it "does not go on without every acceptance" do
    publish("terms", "Termos")
    publish("privacy", "Política")
    sign_in

    post "/first-access/terms", params: { accept: { terms: "1" } }

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("marque o aceite de todos os textos")
    expect(user.consents).to be_empty
  end

  it "keeps the panel closed while no text is published (D-578)" do
    sign_in

    get "/"
    expect(response).to redirect_to("/first-access/terms")

    get "/first-access/terms"
    expect(response.body).to include("ainda não foram publicados")
  end
end
