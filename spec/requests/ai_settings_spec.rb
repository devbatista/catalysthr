require "rails_helper"

# Spec 14, block 14a (D-670): the HR administrator turns the company's AI functions on and off
# (RN-14-010 to RN-14-012, D-389); the CatalystHR team schedules the credits' weights, sets a
# company's cap and releases a pause (RN-14-110, RN-14-114, P-14-36). All behind the `ai` flag.
RSpec.describe "AI settings", type: :request do
  let(:company) { create(:company, name: "Metalúrgica Serra Azul") }
  let(:brand) { create(:brand, owner: company, commercial_name: "Serra Azul RH") }
  let!(:hr_user) { enable_mfa(create(:user, name: "Juliana Ribeiro", cpf: "98765432100")) }
  let!(:hr) { create(:membership, user: hr_user, organization: company, roles: %w[hr_admin]) }

  before do
    travel_to Time.zone.local(2026, 11, 10, 10)
    Flipper.enable(FeatureFlags::SIGN_IN)
    Flipper.enable(FeatureFlags::AI)
    publish_platform_legal_documents
  end

  after { travel_back }

  def in_company(&) = ActsAsTenant.with_tenant(company, &)

  def panel_sign_in(user)
    brand.subdomains.create!(slug: "serraazul") unless brand.subdomains.exists?
    host! "serraazul.painel.catalysthr.com.br"
    accept_legal_documents(user, brand)
    sign_in_with_mfa(user.cpf, user)
  end

  def admin_sign_in(role, cpf: "52998224725")
    host! "admin.catalysthr.com.br"
    user = enable_mfa(create(:user, platform_role: role, cpf: cpf, name: "Paulo Lima #{role}"))
    sign_in_with_mfa(cpf, user)
    user
  end

  describe "the company's functions" do
    it "lets the HR administrator turn a function off and on again, with the trail (RN-14-010, RN-14-012)" do
      panel_sign_in(hr_user)
      get "/settings/edit"
      expect(response.body).to include("Funções de IA", "/settings/ai/edit")

      get "/settings/ai/edit"
      expect(response.body).to include("Leitura de documentos", "Distribuição do lote", "0 de 200 créditos")
      expect(response.body).not_to include('data-ai-feature="assistant"', 'data-ai-feature="recruitment"')

      patch "/settings/ai", params: { enabled: %w[batch_classification] }
      expect(response).to redirect_to("/settings/ai/edit")
      setting = in_company { CompanyAiSetting.sole }
      expect(setting).to have_attributes(feature: "document_extraction", enabled: false, updated_by: hr_user)
      expect(Ai::Availability.check(company, "document_extraction")).to eq(:unavailable) # no key in the specs
      expect(Ai::Availability.enabled?(company, "document_extraction")).to be(false)
      expect(Ai::Availability.enabled?(company, "batch_classification")).to be(true)

      patch "/settings/ai", params: { enabled: %w[document_extraction batch_classification] }
      expect(in_company { CompanyAiSetting.sole.enabled }).to be(true)
      expect(PaperTrail::Version.where(item_type: "CompanyAiSetting", item_id: setting.id).count).to eq(2)
    end

    it "shows the pause of the daily cap" do
      AiDailyCap.create!(company: company, date: Date.current, cap_credits: 200, used_credits: 200, paused_at: Time.current)
      panel_sign_in(hr_user)
      get "/settings/ai/edit"
      expect(response.body).to include("200 de 200 créditos", "pausada até a meia-noite")
    end

    it "is only the HR administrator's, and answers 404 with the flag off" do
      analyst_user = enable_mfa(create(:user, name: "Rui Costa", cpf: "39053344705"))
      create(:membership, user: analyst_user, organization: company, roles: %w[hr_analyst], status: "active")
      panel_sign_in(analyst_user)
      get "/settings/ai/edit"
      expect(response).to have_http_status(:forbidden)
      patch "/settings/ai", params: { enabled: [] }
      expect(response).to have_http_status(:forbidden)
      expect(in_company { CompanyAiSetting.count }).to eq(0)

      delete "/sign-out"
      Flipper.disable(FeatureFlags::AI)
      panel_sign_in(hr_user)
      get "/settings/edit"
      expect(response.body).not_to include("/settings/ai/edit")
      get "/settings/ai/edit"
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "the CatalystHR team" do
    it "lets the superadmin schedule a weight, set a company's cap and release its pause (RN-14-110, RN-14-114)" do
      superadmin = admin_sign_in("superadmin")
      get "/ai"
      expect(response.body).to include("Pesos dos créditos", "Leitura de documentos", "Peso da spec, sem mudanças")

      post "/ai/weights", params: { ai_credit_weight: { feature: "document_extraction", credits: 2, valid_from: "2026-11-10" } }
      expect(flash[:alert]).to include("a partir de amanhã")
      post "/ai/weights", params: { ai_credit_weight: { feature: "document_extraction", credits: 2, valid_from: "2026-12-01" } }
      expect(AiCreditWeight.sole).to have_attributes(credits: 2, unit: "request", valid_from: Date.new(2026, 12, 1), created_by: superadmin)
      get "/ai"
      expect(response.body).to include("2 a partir de 01/12/2026")
      expect(AiCreditWeight.credits_on("document_extraction")).to eq(1)

      cap = AiDailyCap.create!(company: company, date: Date.current, cap_credits: 200, used_credits: 200, paused_at: Time.current)
      get "/ai"
      expect(response.body).to include("Metalúrgica Serra Azul", "Pausada pelo teto")
      get "/ai", params: { q: "serra" }
      expect(response.body).to include("/ai/companies/#{company.id}")

      get "/ai/companies/#{company.id}"
      expect(response.body).to include("200 de 200 créditos", "Liberar a pausa de hoje")
      patch "/ai/companies/#{company.id}/cap", params: { ai_daily_cap_credits: "abc" }
      expect(flash[:alert]).to include("número inteiro")
      patch "/ai/companies/#{company.id}/cap", params: { ai_daily_cap_credits: "500" }
      expect(company.reload.ai_daily_cap_credits).to eq(500)
      expect(cap.reload).to have_attributes(cap_credits: 500, paused?: false)

      cap.update!(paused_at: Time.current)
      post "/ai/companies/#{company.id}/release"
      expect(cap.reload).to have_attributes(released_by: superadmin, paused?: false)

      patch "/ai/companies/#{company.id}/cap", params: { ai_daily_cap_credits: "" }
      expect(company.reload.ai_daily_cap_credits).to be_nil
    end

    it "lets the support release a pause but not change weights or caps, and the finance team only read" do
      cap = AiDailyCap.create!(company: company, date: Date.current, cap_credits: 200, used_credits: 200, paused_at: Time.current)
      support = admin_sign_in("support")
      get "/ai/companies/#{company.id}"
      expect(response.body).to include("Liberar a pausa de hoje")
      expect(response.body).not_to include("Salvar o teto")
      patch "/ai/companies/#{company.id}/cap", params: { ai_daily_cap_credits: "500" }
      expect(response).to have_http_status(:forbidden)
      post "/ai/weights", params: { ai_credit_weight: { feature: "writing", credits: 2, valid_from: "2026-12-01" } }
      expect(response).to have_http_status(:forbidden)
      post "/ai/companies/#{company.id}/release"
      expect(cap.reload.released_by).to eq(support)

      delete "/sign-out"
      admin_sign_in("finance", cpf: "11144477735")
      get "/ai"
      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include("Agendar o peso")
      cap.update!(released_at: nil, released_by: nil)
      post "/ai/companies/#{company.id}/release"
      expect(response).to have_http_status(:forbidden)
    end

    it "answers 404 with the flag off" do
      admin_sign_in("superadmin")
      Flipper.disable(FeatureFlags::AI)
      get "/ai"
      expect(response).to have_http_status(:not_found)
      expect(response.body).not_to include('href="/ai"')
    end
  end
end
