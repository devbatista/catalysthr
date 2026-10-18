require "rails_helper"

# Spec 05, RN-05-020 and RN-05-021: access events of kind auth, written in the request.
RSpec.describe "Access events of sign-in and security", type: :request do
  include ActiveJob::TestHelper

  let(:partner) { create(:partner) }
  let(:brand) { create(:brand, owner: partner) }
  let(:company) { create(:company, partner: partner) }
  let!(:user) { create(:user, cpf: "12345678909", email: "maria@example.com") }

  before do
    create(:membership, user: user, organization: company, roles: %w[manager])
    brand.subdomains.create!(slug: "aurora")
    Flipper.enable(FeatureFlags::SIGN_IN)
    publish_platform_legal_documents
    accept_legal_documents(user, brand)
    host! "aurora.painel.catalysthr.com.br"
  end

  def actions
    AccessEvent.where(user: user).order(:id).pluck(:action)
  end

  def sign_in_with(password = "Catalyst#2026")
    post "/sign-in", params: { user: { login: "12345678909", password: password } }, headers: { "User-Agent" => "Navegador de teste" }
  end

  it "records sign-in and sign-out with the IP, the browser and the request id" do
    sign_in_with
    delete "/sign-out"

    event = AccessEvent.find_by!(action: "sign_in")
    expect(event).to have_attributes(kind: "auth", user: user, ip: "127.0.0.1", user_agent: "Navegador de teste")
    expect(event.request_id).to be_present
    expect(event.metadata).to eq("area" => "panel", "brand_id" => brand.id)
    expect(actions).to eq(%w[sign_in sign_out])
  end

  it "records failed attempts, the lockout and the unlock" do
    perform_enqueued_jobs { 5.times { sign_in_with("Errada#2026") } }
    unlock_link = ActionMailer::Base.deliveries.last.text_part.body.to_s[%r{https?://\S+}]
    get unlock_link

    expect(actions).to eq(Array.new(4, "sign_in_failed") + %w[locked sign_in_failed unlocked])
    # The lockout is a notice in the bell only; the unlock e-mail is the access notice (D-607).
    expect(Notification.sole).to have_attributes(notification_type: "security.account_locked", in_bell: true)
    expect(NotificationDelivery.count).to eq(0)
  end

  it "does not record attempts with an unknown CPF" do
    post "/sign-in", params: { user: { login: "11144477735", password: "Errada#2026" } }

    expect(AccessEvent.count).to eq(0)
  end

  it "records the password change, the MFA and the remembered device" do
    sign_in_with
    patch "/security/password", params: { user: { current_password: "Catalyst#2026", password: "Nova#Senha2026",
      password_confirmation: "Nova#Senha2026" } }

    get "/security/mfa/new"
    post "/security/mfa", params: { otp_code: ROTP::TOTP.new(session[Account::MfaController::SECRET_KEY]).now }
    delete "/sign-out"

    travel 1.minute do
      post "/sign-in", params: { user: { login: "12345678909", password: "Nova#Senha2026" } }
      post "/sign-in/code", params: { otp_code: "000000" }
      post "/sign-in/code", params: { otp_code: user.reload.current_otp, remember_device: "1" }
    end

    expect(actions).to eq(%w[sign_in password_changed mfa_enabled sign_out sign_in_failed trusted_device_remembered sign_in])
    expect(AccessEvent.find_by!(action: "sign_in_failed").metadata).to eq("step" => "second_factor")
  end

  it "records who changed what through a page, with whodunnit, IP and request id" do
    superadmin = enable_mfa(create(:user, platform_role: "superadmin", cpf: "52998224725"))
    host! "admin.catalysthr.com.br"
    sign_in_with_mfa("52998224725", superadmin)

    post "/legal-documents", params: { legal_document: { kind: "terms", body: "Nova versão" } }

    version = LegalDocument.last.versions.sole
    expect(version).to have_attributes(event: "create", whodunnit: superadmin.id.to_s, ip: "127.0.0.1")
    expect(version.request_id).to be_present
  end
end
