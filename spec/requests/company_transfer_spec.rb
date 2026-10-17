require "rails_helper"

# Spec 01, RN-01-050 to RN-01-052, CA-01-012 and D-599: the superadmin transfers a
# company in the admin area.
RSpec.describe "Company transfer", type: :request do
  include ActiveJob::TestHelper

  let(:aurora) { create(:partner, name: "Aurora Gestão de Pessoas") }
  let(:boreal) { create(:partner, name: "Boreal Consultoria") }
  let!(:company) { create(:company, partner: aurora, name: "Padaria Pão Quente") }
  let!(:superadmin) { enable_mfa(create(:user, cpf: "52998224725", platform_role: "superadmin")) }
  let(:aurora_brand) { create(:brand, owner: aurora, commercial_name: "Aurora RH") }
  let(:boreal_brand) { create(:brand, owner: boreal, commercial_name: "Boreal RH") }

  before do
    aurora_brand.subdomains.create!(slug: "aurora")
    boreal_brand.subdomains.create!(slug: "boreal")
    Flipper.enable(FeatureFlags::SIGN_IN)
    Flipper.enable(FeatureFlags::COMPANY_TRANSFER)
    publish_platform_legal_documents
  end

  def sign_in_at_admin(user = superadmin, cpf = "52998224725")
    host! "admin.catalysthr.com.br"
    sign_in_with_mfa(cpf, user)
  end

  it "transfers the company with the authorization and shows the new owner" do
    sign_in_at_admin

    get "/company-transfers/new", params: { q: "Padaria" }
    expect(response.body).to include("Padaria Pão Quente", "Boreal Consultoria", "Transferir empresa")

    post "/company-transfers", params: { company_id: company.id, to_partner_id: boreal.id,
      authorized_by_text: "Aceite por e-mail da RH administradora em 15/10/2026" }

    expect(response).to redirect_to("/company-transfers/new")
    follow_redirect!
    expect(response.body).to include("Padaria Pão Quente transferida. Novo dono: Boreal Consultoria.")
    expect(company.reload.partner).to eq(boreal)
  end

  it "shows why the transfer was refused" do
    sign_in_at_admin

    post "/company-transfers", params: { company_id: company.id, to_partner_id: "direct", authorized_by_text: "Pedido da empresa" }

    follow_redirect!
    expect(response.body).to include("Informe o endereço da empresa direta.")
    expect(company.reload.partner).to eq(aurora)
  end

  it "is only for the superadmin (spec 01, section 6)" do
    support = enable_mfa(create(:user, cpf: "11144477735", platform_role: "support"))
    sign_in_at_admin(support, "11144477735")

    get "/company-transfers/new"
    expect(response).to have_http_status(:forbidden)
    get "/"
    expect(response.body).not_to include("Transferir empresa")
  end

  it "answers 404 while the flag is off" do
    Flipper.disable(FeatureFlags::COMPANY_TRANSFER)
    sign_in_at_admin

    get "/company-transfers/new"
    expect(response).to have_http_status(:not_found)
    get "/"
    expect(response.body).not_to include("Transferir empresa")
  end

  # CA-01-012
  it "takes the company away from the old partner's consultant and keeps its users' login at the new subdomain" do
    consultant = enable_mfa(create(:user, cpf: "98765432100"))
    membership = create(:membership, user: consultant, organization: aurora, roles: %w[consultant])
    membership.partner_membership_companies.create!(company: company)
    hr = enable_mfa(create(:user, cpf: "12345678909"))
    create(:membership, user: hr, organization: company, roles: %w[hr_admin])
    accept_legal_documents(consultant, aurora_brand)
    accept_legal_documents(hr, boreal_brand)

    Companies::Transfer.call(company: company, to_partner: boreal, performed_by: superadmin, authorized_by_text: "Pedido da empresa")

    host! "aurora.painel.catalysthr.com.br"
    sign_in_with_mfa("98765432100", consultant)
    get "/companies"
    expect(response.body).not_to include("Padaria Pão Quente")
    post "/current-company", params: { company_id: company.id }
    expect(response).to have_http_status(:not_found)

    delete "/sign-out"
    host! "boreal.painel.catalysthr.com.br"
    sign_in_with_mfa("12345678909", hr)
    get "/"
    expect(response.body).to include("Empresa: Padaria Pão Quente.")
  end
end
