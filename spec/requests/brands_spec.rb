require "rails_helper"

# Spec 01, RN-01-030 to RN-01-035, RN-01-022 and section 6: editing the brands.
RSpec.describe "Brands", type: :request do
  let(:partner) { create(:partner, name: "Aurora Gestão de Pessoas") }
  let!(:brand) { create(:brand, owner: partner, commercial_name: "Aurora RH") }
  let!(:padaria) { create(:company, partner: partner, name: "Padaria Pão Quente") }

  before do
    brand.subdomains.create!(slug: "aurora")
    Flipper.enable(FeatureFlags::SIGN_IN)
    publish_platform_legal_documents
  end

  describe "in the partner's panel" do
    let!(:admin) { enable_mfa(create(:user, cpf: "98765432100")) }

    before do
      create(:membership, user: admin, organization: partner, roles: %w[partner_admin])
      accept_legal_documents(admin, brand)
      host! "aurora.painel.catalysthr.com.br"
      sign_in_with_mfa("98765432100", admin)
    end

    it "edits the partner's brand, which the pages use at once (RN-01-031)" do
      patch "/partner/brand", params: { brand: { commercial_name: "Aurora Pessoas", primary_color: "#6b2fa3",
        login_welcome_text: "Bem-vindo à Aurora", support_email: "ajuda@aurora.example" } }

      expect(response).to redirect_to("/partner/brand/edit")
      expect(brand.reload).to have_attributes(commercial_name: "Aurora Pessoas", primary_color: "#6B2FA3")
      get "/partner"
      expect(response.body).to include("--brand-primary: #6B2FA3", "Aurora Pessoas")
    end

    it "refuses a primary color without contrast, saying why (CA-01-010)" do
      patch "/partner/brand", params: { brand: { commercial_name: "Aurora RH", primary_color: "#FFFF00" } }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("4,5:1")
      expect(brand.reload.primary_color).to be_nil
    end

    it "creates the client company's brand and chooses the mode (RN-01-034, D-165)" do
      patch "/partner/companies/#{padaria.id}/brand", params: { brand: { commercial_name: "Padaria", primary_color: "#9E3422",
        login_welcome_text: "ignorado" }, brand_display_mode: "replace" }

      expect(response).to redirect_to("/partner/companies/#{padaria.id}/brand/edit")
      expect(padaria.reload.brand).to have_attributes(commercial_name: "Padaria", primary_color: "#9E3422", login_welcome_text: nil)
      expect(padaria.brand_display_mode).to eq("replace")
    end

    it "does not reach another partner's company (RN-01-013)" do
      get "/partner/companies/#{create(:company, :with_partner).id}/brand/edit"

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "the display mode after sign-in (RN-01-034, RN-01-035)" do
    let!(:hr_admin) { enable_mfa(create(:user, cpf: "98765432100")) }

    before do
      create(:membership, user: hr_admin, organization: padaria, roles: %w[hr_admin])
      brand.update!(secondary_color: "#112233")
      create(:brand, owner: padaria, commercial_name: "Padaria Pão Quente", primary_color: "#9E3422")
      accept_legal_documents(hr_admin, brand)
      host! "aurora.painel.catalysthr.com.br"
      sign_in_with_mfa("98765432100", hr_admin)
    end

    it "keeps the partner's brand alongside the company" do
      get "/"

      expect(response.body).to include("--brand-primary: #{Brand::DEFAULT_COLORS[:primary]}", "Aurora RH")
    end

    it "puts the company's brand in place, with the partner's colors where it has none" do
      padaria.update!(brand_display_mode: "replace")

      get "/"

      expect(response.body).to include("--brand-primary: #9E3422", "--brand-secondary: #112233")
      expect(response.body).to match(%r{href="/">\s*<span[^>]*>Padaria Pão Quente</span>})
    end
  end

  describe "in the admin area" do
    let!(:superadmin) { enable_mfa(create(:user, cpf: "52998224725", platform_role: "superadmin")) }

    before do
      host! "admin.catalysthr.com.br"
      sign_in_with_mfa("52998224725", superadmin)
    end

    it "lists the brands with the partner's companies and edits them" do
      get "/brands"
      expect(response.body).to include("Aurora RH", "Padaria Pão Quente", "aurora")

      patch "/brands/#{brand.id}", params: { brand: { commercial_name: "Aurora", support_phone: "1140028922" } }
      expect(brand.reload).to have_attributes(commercial_name: "Aurora", support_phone: "1140028922")

      patch "/companies/#{padaria.id}/brand", params: { brand: { commercial_name: "Padaria" }, brand_display_mode: "replace" }
      expect(padaria.reload.brand_display_mode).to eq("replace")
    end

    it "changes the slug, and the old one redirects (RN-01-022, CA-01-006)" do
      patch "/brands/#{brand.id}/slug", params: { slug: "auroragp" }

      expect(brand.reload.active_subdomain.slug).to eq("auroragp")
      host! "aurora.painel.catalysthr.com.br"
      get "/sign-in"
      expect(response).to have_http_status(:moved_permanently)
      expect(response.location).to eq("http://auroragp.painel.catalysthr.com.br/sign-in")
    end

    it "refuses a reserved slug (CA-01-013)" do
      patch "/brands/#{brand.id}/slug", params: { slug: "admin" }

      expect(response).to redirect_to("/brands/#{brand.id}/edit")
      expect(brand.reload.active_subdomain.slug).to eq("aurora")
    end
  end

  it "lets the support edit brands but not change slugs (P-01-17)" do
    support = enable_mfa(create(:user, cpf: "52998224725", platform_role: "support"))
    host! "admin.catalysthr.com.br"
    sign_in_with_mfa("52998224725", support)

    patch "/brands/#{brand.id}", params: { brand: { commercial_name: "Aurora" } }
    expect(brand.reload.commercial_name).to eq("Aurora")

    patch "/brands/#{brand.id}/slug", params: { slug: "auroragp" }
    expect(response).to have_http_status(:forbidden)
  end
end
