require "rails_helper"

# Spec 15, RN-15-001 (D-607, D-608): the bell in the top bar, the list of the last 90
# days, opening a notice and the unread count.
RSpec.describe "Notifications", type: :request do
  let(:company) { create(:company, name: "Metalúrgica Serra Azul") }
  let(:brand) { create(:brand, owner: company, commercial_name: "Serra Azul RH") }
  let!(:hr_admin) { enable_mfa(create(:user, name: "Juliana Ribeiro", cpf: "98765432100")) }
  let!(:membership) { create(:membership, user: hr_admin, organization: company, roles: %w[hr_admin]) }
  let!(:support) { enable_mfa(create(:user, name: "Sofia Suporte", cpf: "52998224725", platform_role: "support")) }

  before do
    brand.subdomains.create!(slug: "serraazul")
    Flipper.enable(FeatureFlags::SIGN_IN)
    publish_platform_legal_documents
    host! "serraazul.painel.catalysthr.com.br"
  end

  def notify(user = hr_admin, **options)
    Notifications.notify!("security.mfa_reset", user: user, membership: membership, path: "/security", brand_name: "Serra Azul RH",
      **options)
  end

  def sign_in_as_hr
    accept_legal_documents(hr_admin, brand)
    sign_in_with_mfa("98765432100", hr_admin)
  end

  it "shows the unread count in the bell, lists the notices and opens one, marking it read" do
    notification = notify
    sign_in_as_hr

    get "/"
    expect(response.body).to include('aria-label="Avisos, 1 não lidos"', 'data-bell="/notifications/unread-count"')

    get "/notifications"
    expect(response.body).to include("Verificação em duas etapas redefinida em Serra Azul RH", "(não lido)")

    get "/notifications/#{notification.id}"
    expect(response).to redirect_to("/security")
    expect(notification.reload).to be_read

    get "/notifications/unread-count"
    expect(response.parsed_body).to eq("count" => 0)
  end

  it "does not count the bell's polling as the person's activity (RN-02-050)" do
    sign_in_as_hr
    session = UserSession.active.sole

    travel 10.minutes do
      expect { get "/notifications/unread-count" }.not_to(change { session.reload.expires_at })
      expect { get "/notifications" }.to(change { session.reload.expires_at })
    end
  end

  it "opens only the person's own notices" do
    other = create(:user, name: "Outra Pessoa")
    create(:membership, user: other, organization: company, roles: %w[manager])
    foreign = Notifications.notify!("security.account_locked", user: other, path: "/security")
    sign_in_as_hr

    get "/notifications/#{foreign.id}"
    expect(response).to have_http_status(:not_found)
    expect(foreign.reload).not_to be_read
  end

  it "does not mark a notice read during an impersonate (RN-02-084)" do
    notification = notify
    host! "admin.catalysthr.com.br"
    sign_in_with_mfa("52998224725", support)
    post "/impersonations", params: { user_id: hr_admin.id, brand_id: brand.id, reason: "Chamado 1" }
    link = response.location
    host! "serraazul.painel.catalysthr.com.br"
    get link

    get "/notifications/#{notification.id}"
    expect(response).to redirect_to("/security")
    expect(notification.reload).not_to be_read
  end

  it "has a bell of its own in the admin" do
    notice = Notifications.notify!("brand.email_domain_status", user: support, brand: brand, area: "admin", path: "/brands/#{brand.id}/edit",
      variant: "failed", domain: "serraazul.com.br", brand_name: "Serra Azul RH")
    host! "admin.catalysthr.com.br"
    sign_in_with_mfa("52998224725", support)

    get "/notifications"
    expect(response.body).to include("A verificação do domínio serraazul.com.br falhou")
    get "/notifications/#{notice.id}"
    expect(response).to redirect_to("/brands/#{brand.id}/edit")
  end
end
