require "rails_helper"

# Spec 19, RN-19-102 (D-632, D-633): the finance team keeps what goes on every NFS-e, and
# the screen shows the Asaas account's own setup, read from Asaas and never kept.
RSpec.describe "Fiscal settings", type: :request do
  before do
    Flipper.enable(FeatureFlags::SIGN_IN)
    Flipper.enable(FeatureFlags::BILLING)
    Flipper.enable(FeatureFlags::NFSE)
    host! "admin.catalysthr.com.br"
  end

  def sign_in(role)
    user = enable_mfa(create(:user, platform_role: role, cpf: "52998224725", name: "Fernanda Financeiro"))
    sign_in_with_mfa("52998224725", user)
    user
  end

  def save(**attributes)
    patch "/fiscal-settings", params: { fiscal_setting: {
      service_code: "010501", service_name: "Licenciamento de programas", nbs_code: "1.1506.21.00",
      operation_indicator_code: "100501", description: "Licenciamento de software CatalystHR por assinatura",
      observations: "Documento emitido por ME ou EPP optante pelo Simples Nacional.", retain_iss: "0",
      pis_rate: "0", cofins_rate: "0", csll_rate: "0", inss_rate: "0", ir_rate: "0"
    }.merge(attributes) }
  end

  it "lets the finance team fill the note's data, from the menu, starting from D-632's values" do
    finance = sign_in("finance")
    configure_asaas
    stub_asaas_fiscal_info

    get "/fiscal-settings"
    expect(response.body).to include("Notas fiscais", "A configuração fiscal ainda não foi preenchida", "Sandbox (testes)",
      "Portal Nacional da NFS-e", "80001")

    get "/fiscal-settings/edit"
    expect(response.body).to include("1.1506.21.00", "100501", "Licenciamento de software CatalystHR por assinatura")

    save(pis_rate: "0.65")

    expect(response).to redirect_to("/fiscal-settings")
    expect(flash[:notice]).to eq("Configuração fiscal salva.")
    expect(FiscalSetting.sole).to have_attributes(service_code: "010501", pis_rate: 0.65, updated_by: finance)
    follow_redirect!
    expect(response.body).to include("010501", "PIS 0,65%", "Fernanda Financeiro")
  end

  it "keeps the form with the errors for an NBS without the dots" do
    sign_in("superadmin")

    save(nbs_code: "115062100")

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("NBS")
    expect(FiscalSetting.count).to eq(0)
  end

  it "says so when the API key is missing or Asaas is out of the air, without breaking the page" do
    sign_in("finance")

    get "/fiscal-settings"
    expect(response.body).to include("A chave da API do Asaas não está configurada")

    configure_asaas
    stub_request(:get, "#{AsaasStub::BASE_URL}/fiscalInfo/").to_timeout
    get "/fiscal-settings"
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Não foi possível consultar o Asaas agora")
  end

  it "says so when the Asaas account has no fiscal setup yet" do
    sign_in("finance")
    configure_asaas
    stub_asaas_fiscal_info({ errors: [] }, status: 404)

    get "/fiscal-settings"

    expect(response.body).to include("A conta do Asaas ainda não tem os dados fiscais")
  end

  it "is not for the support" do
    sign_in("support")

    get "/fiscal-settings"
    expect(response).to have_http_status(:forbidden)
    save
    expect(response).to have_http_status(:forbidden)
  end

  it "answers 404 while the notes are off (D-633)" do
    sign_in("finance")
    Flipper.disable(FeatureFlags::NFSE)

    get "/fiscal-settings"

    expect(response).to have_http_status(:not_found)
  end
end
