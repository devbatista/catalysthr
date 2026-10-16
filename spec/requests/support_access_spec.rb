require "rails_helper"

# D-581, D-593 and P-03-02: the support enters a direct company from the admin area.
RSpec.describe "Support access", type: :request do
  include ActiveSupport::Testing::TimeHelpers

  let(:company) { create(:company, name: "Metalúrgica Serra Azul") }
  let(:brand) { create(:brand, owner: company, commercial_name: "Serra Azul RH") }
  let!(:support) { enable_mfa(create(:user, name: "Sofia Suporte", cpf: "52998224725", platform_role: "support")) }

  before do
    brand.subdomains.create!(slug: "serraazul")
    Flipper.enable(FeatureFlags::SIGN_IN)
    publish_platform_legal_documents
  end

  def sign_in_at_admin(user = support, cpf = "52998224725")
    host! "admin.catalysthr.com.br"
    sign_in_with_mfa(cpf, user)
  end

  def enter_company(reason: "Implantação, chamado 77")
    sign_in_at_admin
    post "/support-accesses", params: { company_id: company.id, reason: reason }
    link = response.location
    host! "serraazul.painel.catalysthr.com.br"
    get link
    link
  end

  it "lists only direct companies" do
    create(:company, :with_partner, name: "Metalúrgica Parceira")
    sign_in_at_admin

    get "/support-accesses/new", params: { q: "Metalúrgica" }

    expect(response.body).to include("Metalúrgica Serra Azul")
    expect(response.body).not_to include("Metalúrgica Parceira")
  end

  it "opens the company as a consultant, with the banner, and records the entry (D-581)" do
    link = enter_company

    expect(link).to start_with("http://serraazul.painel.catalysthr.com.br/support-access?token=")
    get "/"
    expect(response.body).to include("Suporte CatalystHR em Metalúrgica Serra Azul", "Empresa: Metalúrgica Serra Azul.")
    expect(SupportAccess.sole).to have_attributes(support_user: support, company: company, reason: "Implantação, chamado 77")
    expect(AccessEvent.find_by!(action: "support_access_started")).to have_attributes(user: support, company: company,
      metadata: { "reason" => "Implantação, chamado 77" })

    # An HR analyst does not manage the company's users (spec 03, section 4.2).
    get "/users"
    expect(response).to have_http_status(:forbidden)
  end

  it "uses the link once" do
    link = enter_company
    reset!
    host! "serraazul.painel.catalysthr.com.br"

    get link

    expect(response).to have_http_status(:not_found)
  end

  it "ends on leaving, signing the support out of the subdomain" do
    enter_company

    delete "/support-access"

    expect(response).to redirect_to("http://admin.catalysthr.com.br/support-accesses/new")
    expect(SupportAccess.sole).to have_attributes(ended_reason: "manual")
    expect(AccessEvent.find_by!(action: "support_access_ended").metadata).to eq("reason" => "manual")
    get "/"
    expect(response).to redirect_to("/sign-in")
  end

  it "ends after 30 minutes without use (RN-02-050)" do
    enter_company

    travel 31.minutes do
      get "/"
      get "/"

      expect(response).to redirect_to("http://admin.catalysthr.com.br/support-accesses/new")
      expect(SupportAccess.sole).to have_attributes(ended_reason: "timeout")
    end
  end

  it "does not enter a partner's company, which the support only sees by impersonate (P-03-02)" do
    partner_company = create(:company, :with_partner)
    create(:brand, owner: partner_company.partner).subdomains.create!(slug: "aurora")
    sign_in_at_admin

    post "/support-accesses", params: { company_id: partner_company.id, reason: "Chamado" }

    expect(response).to redirect_to(%r{/support-accesses/new})
    expect(SupportAccess.count).to eq(0)
  end

  it "is only for the support, not for the superadmin (P-03-03)" do
    superadmin = enable_mfa(create(:user, cpf: "11144477735", platform_role: "superadmin"))
    sign_in_at_admin(superadmin, "11144477735")

    get "/support-accesses/new"

    expect(response).to have_http_status(:forbidden)
  end
end
