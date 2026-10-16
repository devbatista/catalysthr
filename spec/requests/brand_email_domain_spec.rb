require "rails_helper"

# Spec 01, RN-01-040, section 6 and D-596: registering the brand's e-mail domain.
RSpec.describe "Brand e-mail domain", type: :request do
  let(:partner) { create(:partner, name: "Aurora Gestão de Pessoas") }
  let!(:brand) { create(:brand, owner: partner, commercial_name: "Aurora RH") }

  before do
    brand.subdomains.create!(slug: "aurora")
    Flipper.enable(FeatureFlags::SIGN_IN)
    Flipper.enable(FeatureFlags::BRAND_EMAIL_DOMAIN)
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

    it "registers the domain and shows the status and the DNS records" do
      stub_ses

      post "/partner/brand/email-domain", params: { email_domain: "auroragestao.com.br" }
      expect(response).to redirect_to("/partner/brand/edit")
      follow_redirect!

      expect(response.body).to include("Domínio cadastrado", "auroragestao.com.br", "pendente de verificação",
        "tok1abc._domainkey.auroragestao.com.br", "bounce.auroragestao.com.br", "v=spf1 include:amazonses.com ~all",
        "Os e-mails saem de no-reply@catalysthr.com.br")
      expect(brand.reload.email_domain_registered_by).to eq(admin)
    end

    it "shows why a domain is refused" do
      stub_ses

      post "/partner/brand/email-domain", params: { email_domain: "catalysthr.com.br" }
      follow_redirect!

      expect(response.body).to include("não pode ser usado")
      expect(brand.reload.email_domain).to be_nil
    end

    it "removes the domain" do
      stub_ses
      brand.update!(email_domain: "aurora.com.br", email_domain_status: "verified")

      delete "/partner/brand/email-domain"

      expect(response).to redirect_to("/partner/brand/edit")
      expect(brand.reload.email_domain).to be_nil
    end

    it "is closed while the feature is off (P-20-11)" do
      Flipper.disable(FeatureFlags::BRAND_EMAIL_DOMAIN)

      post "/partner/brand/email-domain", params: { email_domain: "auroragestao.com.br" }
      expect(response).to have_http_status(:not_found)

      get "/partner/brand/edit"
      expect(response.body).not_to include("Domínio de e-mail")
    end
  end

  it "is not open to the partner's consultant (spec 01, section 6)" do
    consultant = enable_mfa(create(:user, cpf: "98765432100"))
    create(:membership, user: consultant, organization: partner, roles: %w[consultant])
    accept_legal_documents(consultant, brand)
    host! "aurora.painel.catalysthr.com.br"
    sign_in_with_mfa("98765432100", consultant)

    post "/partner/brand/email-domain", params: { email_domain: "auroragestao.com.br" }

    expect(response).to have_http_status(:forbidden)
    expect(brand.reload.email_domain).to be_nil
  end

  describe "in the admin area" do
    let!(:support) { enable_mfa(create(:user, cpf: "52998224725", platform_role: "support")) }

    before do
      host! "admin.catalysthr.com.br"
      sign_in_with_mfa("52998224725", support)
    end

    it "registers the domain of a direct company's brand" do
      stub_ses
      direct = create(:company, name: "Metalúrgica Serra Azul")
      direct_brand = create(:brand, owner: direct, commercial_name: "Serra Azul")
      direct_brand.subdomains.create!(slug: "serraazul")

      post "/brands/#{direct_brand.id}/email-domain", params: { email_domain: "serraazul.com.br" }

      expect(response).to redirect_to("/brands/#{direct_brand.id}/edit")
      expect(direct_brand.reload).to have_attributes(email_domain: "serraazul.com.br", email_domain_registered_by: support)
      get "/brands/#{direct_brand.id}/edit"
      expect(response.body).to include("Domínio de e-mail", "tok1abc._domainkey.serraazul.com.br")
    end

    it "does not give a domain to a partner's company with its own brand, which sends from the partner's (P-01-18)" do
      company_brand = create(:brand, owner: create(:company, partner: partner))

      post "/brands/#{company_brand.id}/email-domain", params: { email_domain: "padaria.com.br" }

      expect(response).to have_http_status(:not_found)
    end
  end
end
