require "rails_helper"

# Spec 08, RN-08-001 (D-270, D-642): the CatalystHR team keeps the platform's document types
# in the admin's content (RN-19-080).
RSpec.describe "Admin document types", type: :request do
  before do
    Flipper.enable(FeatureFlags::SIGN_IN)
    host! "admin.catalysthr.com.br"
    load_platform_document_types
  end

  def sign_in(role)
    user = enable_mfa(create(:user, platform_role: role, cpf: "52998224725", name: "Paulo Lima"))
    sign_in_with_mfa("52998224725", user)
    user
  end

  it "lets the support list, create and archive a platform type" do
    sign_in("support")

    get "/document-types"
    expect(response.body).to include("Tipos de documento", 'href="/document-types"', "Comprovante de residência",
      "Aceito até 90 dias depois da emissão", "ASO periódico", "A cada 12 meses")

    post "/document-types", params: { document_type: { code: "nr35", name: "Certificado NR-35", category: "other",
      expiration_rule: "periodicity", expiration_months: "24", alert_days: "30", max_files: "1" } }
    type = PlatformDocumentType.find_by!(code: "nr35")
    expect(response).to redirect_to("/document-types")
    expect(type).to have_attributes(company_id: nil, expiration_months: 24)

    patch "/document-types/#{type.id}", params: { document_type: { code: "other", status: "archived" } }
    expect(type.reload).to have_attributes(code: "nr35", status: "archived")
  end

  it "refuses a code already taken or out of format" do
    sign_in("superadmin")

    post "/document-types", params: { document_type: { code: "rg", name: "RG novo", category: "personal", alert_days: "30", max_files: "1" } }
    expect(response).to have_http_status(:unprocessable_content)

    post "/document-types", params: { document_type: { code: "RG Novo", name: "RG novo", category: "personal", alert_days: "30", max_files: "1" } }
    expect(response.body).to include("só aceita letras minúsculas, números e sublinhado")
  end

  it "keeps the finance team out" do
    sign_in("finance")

    get "/document-types"
    expect(response).to have_http_status(:forbidden)
  end
end
