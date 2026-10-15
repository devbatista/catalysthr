require "rails_helper"

# Spec 01, RN-01-004 and RN-01-005: the current company after sign-in.
RSpec.describe "Current company", type: :request do
  let(:partner) { create(:partner) }
  let(:brand) { create(:brand, owner: partner) }
  let(:padaria) { create(:company, partner: partner, name: "Padaria Pão Quente") }
  let(:transportes) { create(:company, partner: partner, name: "Transportes Rápidos") }
  let!(:user) { create(:user, cpf: "12345678909") }

  before do
    brand.subdomains.create!(slug: "aurora")
    Flipper.enable(FeatureFlags::SIGN_IN)
    publish_platform_legal_documents
    accept_legal_documents(user, brand)
    host! "aurora.painel.catalysthr.com.br"
  end

  def sign_in
    post "/sign-in", params: { user: { login: "12345678909", password: "Catalyst#2026" } }
  end

  it "opens the only company at once (RN-01-004)" do
    create(:membership, user: user, organization: padaria, roles: %w[manager])
    sign_in

    get "/"
    expect(response.body).to include("Empresa: Padaria Pão Quente.")
  end

  it "asks to choose with more than one company, and switches only to authorized ones (RN-01-005)" do
    create(:membership, user: user, organization: padaria, roles: %w[manager])
    create(:membership, user: user, organization: transportes, roles: %w[manager])
    outsider = create(:company, partner: partner, name: "Outra Empresa")
    sign_in

    get "/"
    expect(response).to redirect_to("/companies")
    get "/companies"
    expect(response.body).to include("Padaria Pão Quente", "Transportes Rápidos")
    expect(response.body).not_to include("Outra Empresa")

    post "/current-company", params: { company_id: transportes.id }
    get "/"
    expect(response.body).to include("Empresa: Transportes Rápidos.")

    post "/current-company", params: { company_id: outsider.id }
    expect(response).to have_http_status(:not_found)
    get "/"
    expect(response.body).to include("Empresa: Transportes Rápidos.")
  end

  it "sets the company as the request's tenant (RN-01-010)" do
    create(:membership, user: user, organization: padaria, roles: %w[manager])
    tenants = []
    allow_any_instance_of(Panel::HomeController).to receive(:index).and_wrap_original do |method|
      tenants << ActsAsTenant.current_tenant
      method.call
    end
    sign_in

    get "/"
    expect(tenants).to eq([ padaria ])
  end

  it "drops a company whose access was removed" do
    membership = create(:membership, user: user, organization: padaria, roles: %w[manager])
    create(:membership, user: user, organization: transportes, roles: %w[manager])
    sign_in
    post "/current-company", params: { company_id: padaria.id }

    membership.update_columns(status: "revoked")
    get "/"

    expect(response.body).to include("Empresa: Transportes Rápidos.")
  end
end
