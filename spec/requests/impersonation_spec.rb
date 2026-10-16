require "rails_helper"

# Spec 02, RN-02-080 to RN-02-088 (D-185 to D-187): the support sees the system as a
# client's user, read only, with simulated writes.
RSpec.describe "Impersonation", type: :request do
  include ActiveJob::TestHelper
  include ActiveSupport::Testing::TimeHelpers

  let(:company) { create(:company, name: "Metalúrgica Serra Azul") }
  let(:brand) { create(:brand, owner: company, commercial_name: "Serra Azul RH") }
  let!(:hr_admin) { create(:user, name: "Carlos Mendes", cpf: "98765432100") }
  let!(:support) { enable_mfa(create(:user, name: "Sofia Suporte", cpf: "52998224725", platform_role: "support")) }

  before do
    create(:membership, user: hr_admin, organization: company, roles: %w[hr_admin])
    brand.subdomains.create!(slug: "serraazul")
    Flipper.enable(FeatureFlags::SIGN_IN)
    publish_platform_legal_documents
  end

  def on_admin
    host! "admin.catalysthr.com.br"
  end

  def on_panel
    host! "serraazul.painel.catalysthr.com.br"
  end

  # Signs the support in at the admin area and follows the link to the subdomain.
  def start_impersonation(reason: "Chamado 4521")
    on_admin
    sign_in_with_mfa("52998224725", support)
    post "/impersonations", params: { user_id: hr_admin.id, brand_id: brand.id, reason: reason }
    link = response.location
    on_panel
    get link
    link
  end

  it "finds the person by CPF and lists the brands where they have access" do
    on_admin
    sign_in_with_mfa("52998224725", support)

    get "/impersonations/new", params: { cpf: "987.654.321-00" }

    expect(response.body).to include("Carlos Mendes", "Serra Azul RH (serraazul)")
  end

  it "opens the subdomain as the person, with the banner, and records the start and each request (RN-02-082, RN-02-083, RN-02-088)" do
    link = start_impersonation

    expect(link).to start_with("http://serraazul.painel.catalysthr.com.br/impersonation?token=")
    expect(response).to redirect_to("/")
    get "/"

    expect(response.body).to include("Você está vendo como Carlos Mendes", "Encerrar", "Empresa: Metalúrgica Serra Azul.")
    expect(response.body).not_to include("Segurança")
    impersonation = ImpersonationSession.sole
    expect(impersonation).to have_attributes(impersonator: support, impersonated_user: hr_admin, reason: "Chamado 4521")
    expect(impersonation.expires_at).to be_within(5.seconds).of(30.minutes.from_now)
    events = AccessEvent.where(kind: "impersonation")
    expect(events.pluck(:action)).to include("start", "request")
    expect(events.find_by!(action: "start")).to have_attributes(user: hr_admin, impersonator: support,
      metadata: { "reason" => "Chamado 4521" })
  end

  it "uses the link once (RN-02-082)" do
    link = start_impersonation
    reset!
    on_panel

    get link

    expect(response).to have_http_status(:not_found)
    expect(response.body).to include("Link expirado")
  end

  it "uses the link only at its brand and within two minutes" do
    on_admin
    sign_in_with_mfa("52998224725", support)
    post "/impersonations", params: { user_id: hr_admin.id, brand_id: brand.id, reason: "Chamado 1" }
    token = Rack::Utils.parse_query(URI(response.location).query)["token"]
    other = create(:brand, owner: create(:company))
    other.subdomains.create!(slug: "outra")

    host! "outra.painel.catalysthr.com.br"
    get "/impersonation", params: { token: token }
    expect(response).to have_http_status(:not_found)

    travel 3.minutes
    on_panel
    get "/impersonation", params: { token: token }
    expect(response).to have_http_status(:not_found)
  end

  it "simulates writes: nothing is saved, sent or enqueued (RN-02-084)" do
    start_impersonation

    perform_enqueued_jobs do
      post "/users", params: { invitation: { name: "Joana Prado", cpf: "11144477735", email: "joana@example.com",
        roles: %w[manager], channels: %w[email link] } }
    end

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Simulação: nada foi salvo", "Convite criado para Joana Prado")
    expect(User.find_by(cpf: "11144477735")).to be_nil
    expect(ActionMailer::Base.deliveries).to be_empty
    expect(AccessEvent.where(kind: "impersonation", action: "request").pluck(:metadata))
      .to include({ "method" => "POST", "path" => "/users" })
  end

  it "shows the simulation notice after a redirect, with the data unchanged" do
    member = create(:membership, organization: company, roles: %w[hr_analyst])
    start_impersonation

    patch "/users/#{member.id}", params: { membership: { roles: %w[manager] } }
    follow_redirect!

    expect(response.body).to include("Simulação: nada foi salvo")
    expect(member.reload.roles).to eq(%w[hr_analyst])
  end

  it "keeps the person's security pages closed (RN-02-087)" do
    start_impersonation

    get "/security"

    expect(response).to have_http_status(:forbidden)
  end

  it "ends by itself after 30 minutes (RN-02-081)" do
    start_impersonation

    travel 31.minutes do
      get "/"

      expect(response).to redirect_to("http://admin.catalysthr.com.br/impersonations/new")
      expect(ImpersonationSession.sole).to have_attributes(ended_reason: "timeout")
      expect(AccessEvent.find_by!(kind: "impersonation", action: "end").metadata).to eq("reason" => "timeout")
    end
  end

  it "ends with the button and signs the support out of the subdomain" do
    start_impersonation

    delete "/impersonation"

    expect(response).to redirect_to("http://admin.catalysthr.com.br/impersonations/new")
    expect(ImpersonationSession.sole).to have_attributes(ended_reason: "manual")
    get "/"
    expect(response).to redirect_to("/sign-in")
  end

  it "ends when the support signs out" do
    start_impersonation

    delete "/sign-out"

    expect(response).to redirect_to("http://admin.catalysthr.com.br/impersonations/new")
    expect(ImpersonationSession.sole.ended_reason).to eq("manual")
  end

  it "requires a reason" do
    on_admin
    sign_in_with_mfa("52998224725", support)

    post "/impersonations", params: { user_id: hr_admin.id, brand_id: brand.id, reason: " " }

    expect(response).to redirect_to("/impersonations/new?cpf=98765432100")
    expect(ImpersonationSession.count).to eq(0)
  end

  it "is not open to finance, nor to see someone of the CatalystHR team (RN-02-080)" do
    finance = enable_mfa(create(:user, cpf: "11144477735", platform_role: "finance"))
    on_admin
    sign_in_with_mfa("11144477735", finance)

    get "/impersonations/new"
    expect(response).to have_http_status(:forbidden)

    expect(ImpersonationSession.new(impersonator: support, impersonated_user: finance, brand: brand, reason: "x",
      token_expires_at: 1.minute.from_now)).not_to be_valid
  end
end
