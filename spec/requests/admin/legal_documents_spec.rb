require "rails_helper"

# D-579: the superadmin publishes the CatalystHR legal texts.
RSpec.describe "CatalystHR legal texts", type: :request do
  before do
    Flipper.enable(FeatureFlags::SIGN_IN)
    host! "admin.catalysthr.com.br"
  end

  def sign_in(role)
    user = enable_mfa(create(:user, platform_role: role, cpf: "52998224725", name: "Paulo Lima"))
    sign_in_with_mfa("52998224725", user)
    user
  end

  it "lets the superadmin publish new versions, with author and date" do
    superadmin = sign_in("superadmin")

    get "/legal-documents/new", params: { kind: "terms" }
    expect(response).to have_http_status(:ok)

    post "/legal-documents", params: { legal_document: { kind: "terms", body: "Primeira versão" } }
    expect(response).to redirect_to("/legal-documents")
    post "/legal-documents", params: { legal_document: { kind: "terms", body: "Segunda versão" } }

    expect(LegalDocument.platform.terms.pluck(:version)).to contain_exactly(1, 2)
    expect(LegalDocument.platform.last).to have_attributes(published_by: superadmin, brand_id: nil)

    get "/legal-documents"
    expect(response.body).to include("Termos de uso, versão 2", "Paulo Lima", "Segunda versão")
  end

  it "refuses an empty text" do
    sign_in("superadmin")

    post "/legal-documents", params: { legal_document: { kind: "privacy", body: "" } }

    expect(response).to have_http_status(:unprocessable_content)
    expect(LegalDocument.count).to eq(0)
  end

  it "does not let the rest of the team publish (403, RN-03-006)" do
    sign_in("support")

    post "/legal-documents", params: { legal_document: { kind: "terms", body: "Texto" } }
    expect(response).to have_http_status(:forbidden)
    expect(response.body).to include("Acesso negado", "Você não tem permissão para esta ação")

    get "/legal-documents"
    expect(response).to have_http_status(:forbidden)
  end
end
