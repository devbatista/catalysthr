require "rails_helper"

# Spec 15, block 15c (RN-15-003, RN-15-004, D-654): the browser's subscription, the sign-out,
# the invite and "Minhas notificações" in the portal.
RSpec.describe "Push subscriptions", type: :request do
  let(:company) { create(:company) }
  let(:brand) { create(:brand, owner: company, commercial_name: "Serra Azul RH") }
  let(:hr_user) { create(:user) }
  let!(:hr) { create(:membership, user: hr_user, organization: company, roles: %w[hr_admin]) }
  let(:profile) { register_employee(company, by: hr_user, position: create_position(company), name: "Rafael Moura Campos") }
  let(:user) { profile.user }
  let(:membership) { profile.membership }
  let(:endpoint) { "https://fcm.googleapis.com/fcm/send/abc" }
  let(:keys) { { p256dh: Base64.urlsafe_encode64("\x04" + ("a" * 64)), auth: Base64.urlsafe_encode64("b" * 16) } }

  before do
    brand.subdomains.create!(slug: "serraazul")
    Flipper.enable(FeatureFlags::SIGN_IN)
    Flipper.enable(FeatureFlags::PUSH_NOTIFICATIONS)
    publish_platform_legal_documents
    host! "serraazul.painel.catalysthr.com.br"
    user.update!(password: "Catalyst#2026", password_confirmation: "Catalyst#2026")
    ActsAsTenant.with_tenant(company) { membership.update!(status: "active") }
    accept_legal_documents(user, brand)
    post "/sign-in", params: { user: { login: user.cpf, password: "Catalyst#2026" } }
  end

  it "keeps the subscription of the person and the brand" do
    post "/push-subscriptions", params: { endpoint: endpoint, keys: keys }, as: :json

    expect(response).to have_http_status(:no_content)
    expect(PushSubscription.sole).to have_attributes(user: user, brand: brand, endpoint: endpoint)
  end

  it "passes the browser's subscription to who signed in (D-654)" do
    PushSubscription.create!(user: create(:user), brand: brand, endpoint: endpoint, **keys)

    post "/push-subscriptions", params: { endpoint: endpoint, keys: keys }, as: :json

    expect(PushSubscription.sole.user).to eq(user)
  end

  it "refuses an address outside the push services" do
    post "/push-subscriptions", params: { endpoint: "https://169.254.169.254/latest", keys: keys }, as: :json

    expect(response).to have_http_status(:unprocessable_content)
    expect(PushSubscription.count).to eq(0)
  end

  it "does nothing with the flag off" do
    Flipper.disable(FeatureFlags::PUSH_NOTIFICATIONS)

    post "/push-subscriptions", params: { endpoint: endpoint, keys: keys }, as: :json

    expect(response).to have_http_status(:not_found)
  end

  it "removes only the person's own subscription" do
    mine = PushSubscription.create!(user: user, brand: brand, endpoint: endpoint, **keys)
    other = PushSubscription.create!(user: create(:user), brand: brand, endpoint: "#{endpoint}2", **keys)

    delete "/push-subscriptions", params: { endpoint: other.endpoint }, as: :json
    expect(PushSubscription.exists?(other.id)).to be(true)

    delete "/push-subscriptions", params: { endpoint: mine.endpoint }, as: :json
    expect(PushSubscription.exists?(mine.id)).to be(false)
  end

  it "removes this browser's subscription when the person signs out, and only it (D-654)" do
    here = PushSubscription.create!(user: user, brand: brand, endpoint: endpoint, **keys)
    there = PushSubscription.create!(user: user, brand: brand, endpoint: "#{endpoint}2", **keys)

    delete "/sign-out", params: { push_endpoint: here.endpoint }

    expect(PushSubscription.pluck(:id)).to eq([ there.id ])
  end

  it "gives the page the public key and asks to sync once per session" do
    get "/portal/notification-preferences/edit"
    expect(response.body).to match(/data-sync="true"[^>]*>|name="push-public-key"[^>]*data-sync="true"/)

    get "/portal/notification-preferences/edit"
    expect(response.body).to include('data-sync="false"')
  end

  it "has no key on the page with the flag off" do
    Flipper.disable(FeatureFlags::PUSH_NOTIFICATIONS)

    get "/portal/notification-preferences/edit"

    expect(response.body).not_to include("push-public-key", "data-push-device")
  end

  it "shows the invite on the portal's start, after the install invite and before the passkey's (RN-16-022, D-654)" do
    Flipper.enable(FeatureFlags::PASSKEYS)

    get "/portal"

    expect(response.body.index("data-install-invite")).to be < response.body.index("data-push-invite")
    expect(response.body.index("data-push-invite")).to be < response.body.index("data-passkey-invite")
  end

  it "shows the person's channels in the portal, with the device's card and the link in Mais (RN-15-021, D-654)" do
    get "/portal/more"
    expect(response.body).to include("/portal/notification-preferences/edit")

    get "/portal/notification-preferences/edit"
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Minhas notificações", "data-push-device", "preferences[#{membership.id}][documents.requested][]")

    patch "/portal/notification-preferences", params: { preferences: { membership.id => { "documents.requested" => [ "" ] } } }
    expect(response).to redirect_to("/portal/notification-preferences/edit")
    expect(NotificationPreference.find_by(membership: membership, notification_type: "documents.requested").channels).to eq([])
  end

  it "requires a channel on a mandatory type also with the push in the table (CA-15-007)" do
    patch "/portal/notification-preferences", params: { preferences: { membership.id => { "documents.acknowledgment_pending" => [ "" ] } } }

    expect(response).to have_http_status(:unprocessable_content)
  end

  it "does not warn about the missing e-mail when the push is active (RN-15-023)" do
    user.update_columns(email: nil)
    PushSubscription.create!(user: user, brand: brand, endpoint: endpoint, **keys)

    get "/portal/notification-preferences/edit"

    expect(response.body).not_to include("alert-bad")
  end

  it "serves the worker that shows the notice and opens it" do
    get "/service-worker.js"

    expect(response.body).to include('addEventListener("push"', 'addEventListener("notificationclick"', "self.clients.openWindow")
  end
end
