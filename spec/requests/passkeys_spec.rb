require "rails_helper"
require "webauthn/fake_client"

# Spec 16, block 16c (RN-16-070 to RN-16-077, CA-16-009, CA-16-010, D-425, D-426, D-647): the
# passkeys, with the gem's fake authenticator standing for the device. No real device or
# service is called.
RSpec.describe "Passkeys", type: :request do
  include ActiveJob::TestHelper

  let(:company) { create(:company, name: "Metalúrgica Serra Azul") }
  let(:brand) { create(:brand, owner: company, commercial_name: "Aurora RH") }
  let(:password) { "Catalyst#2026" }
  let!(:person) { create(:user, name: "Rafael Moura Campos", cpf: "12345678909", email: "rafael@example.com") }
  let!(:membership) { create(:membership, user: person, organization: company, roles: %w[employee]) }
  let(:origin) { "https://aurora.painel.catalysthr.com.br" }
  let(:device) { WebAuthn::FakeClient.new(origin) }

  before do
    # The challenges live in the cache, which is off in the tests. The request limits, which
    # would share it, have their own test.
    allow(Rails).to receive(:cache).and_return(ActiveSupport::Cache::MemoryStore.new)
    Rack::Attack.enabled = false
    brand.subdomains.create!(slug: "aurora")
    Flipper.enable(FeatureFlags::SIGN_IN)
    Flipper.enable(FeatureFlags::PASSKEYS)
    publish_platform_legal_documents
    host! "aurora.painel.catalysthr.com.br"
    https!
  end

  after { Rack::Attack.enabled = true }

  def sign_in_with_password(login: "12345678909")
    post "/sign-in", params: { user: { login: login, password: password } }
    post "/first-access/terms", params: { accept: { terms: "1", privacy: "1" } }
  end

  def json_post(path, body = {})
    post path, params: body, as: :json
  end

  def ask_registration(nickname: "iPhone", current_password: password)
    json_post "/security/passkeys/challenge", nickname: nickname, current_password: current_password
    response.parsed_body
  end

  def register(nickname: "iPhone", client: device)
    options = ask_registration(nickname: nickname)
    json_post "/security/passkeys", credential: client.create(challenge: options["challenge"], user_verified: true)
    WebauthnCredential.order(:created_at).last
  end

  # Registers one and leaves the session, as the person coming back later.
  def registered_passkey(client: device)
    sign_in_with_password
    passkey = register(client: client)
    delete "/sign-out"
    passkey
  end

  def sign_in_with_passkey(client: device, verified: true, user: person)
    json_post "/sign-in/passkey/challenge"
    challenge = response.parsed_body["challenge"]
    json_post "/sign-in/passkey", credential: client.get(challenge: challenge, user_verified: verified,
      user_handle: WebAuthn.configuration.encoder.decode(user.reload.webauthn_handle))
  end

  describe "registering (RN-16-070)" do
    before { sign_in_with_password }

    it "keeps the public key and tells the person in the bell and by e-mail (D-647)" do
      perform_enqueued_jobs { register(nickname: "  iPhone da Ana  ") }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["redirect_to"]).to eq("/security#passkeys")
      passkey = person.webauthn_credentials.sole
      expect(passkey).to have_attributes(rp_id: "aurora.painel.catalysthr.com.br", nickname: "iPhone da Ana", transports: [ "internal" ])
      expect(passkey.public_key).to be_present
      expect(AccessEvent.find_by!(action: "passkey_added")).to have_attributes(user: person, subject: person)
      notice = Notification.find_by!(notification_type: "security.passkey_added", recipient_user: person)
      expect(notice).to have_attributes(mandatory: true, brand: brand, path: "/security")
      expect(notice.body).to include("iPhone da Ana")
      expect(ActionMailer::Base.deliveries.last.subject).to eq("Nova passkey cadastrada em Aurora RH")
      expect(ActionMailer::Base.deliveries.last.to).to eq([ "rafael@example.com" ])
    end

    it "shows the notice in the bell of the brand" do
      register

      get "/notifications"
      expect(response.body).to include("Nova passkey cadastrada em Aurora RH")
    end

    it "offers the brand's commercial name and the address (CA-16-010, RN-16-074, D-647)" do
      options = ask_registration

      expect(options["rp"]).to eq("name" => "Aurora RH", "id" => "aurora.painel.catalysthr.com.br")
      expect(options["authenticatorSelection"]).to include("residentKey" => "required", "userVerification" => "required")
      expect(options["attestation"]).to eq("none")
    end

    it "gives the device the e-mail and a random identifier, never the CPF (D-647)" do
      options = ask_registration

      expect(options["user"]).to include("name" => "rafael@example.com", "displayName" => "Rafael Moura Campos")
      expect(options["user"]["id"]).to eq(person.reload.webauthn_handle)
      expect(options.to_json).not_to include("12345678909")
    end

    it "gives the device the name when the person has no e-mail (D-647)" do
      person.update!(email: nil, mobile_phone: "11987654321")

      expect(ask_registration["user"]).to include("name" => "Rafael Moura Campos")
    end

    it "keeps the handle after the first passkey" do
      first = ask_registration["user"]["id"]

      expect(ask_registration["user"]["id"]).to eq(first)
    end

    it "refuses a wrong password" do
      ask_registration(current_password: "Errada#2026")

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["error"]).to eq("Senha atual incorreta.")
    end

    it "needs a nickname of at most 60 characters" do
      [ "  ", "x" * 61 ].each do |nickname|
        ask_registration(nickname: nickname)
        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body["error"]).to eq("Dê um nome à passkey, com até 60 caracteres.")
      end
    end

    it "stops at 10 passkeys for the person, also under two ceremonies at once (P-16-17)" do
      options = ask_registration
      10.times do |number|
        person.webauthn_credentials.create!(rp_id: "aurora.painel.catalysthr.com.br", external_id: "id-#{number}", public_key: "x", nickname: "P#{number}")
      end

      json_post "/security/passkeys", credential: device.create(challenge: options["challenge"], user_verified: true)
      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["error"]).to eq("O limite é de 10 passkeys. Remova uma para cadastrar outra.")

      ask_registration
      expect(response).to have_http_status(:unprocessable_content)
      expect(person.webauthn_credentials.active.count).to eq(10)
    end

    it "counts only the active ones" do
      10.times do |number|
        person.webauthn_credentials.create!(rp_id: "aurora.painel.catalysthr.com.br", external_id: "id-#{number}", public_key: "x", nickname: "P#{number}",
          removed_at: Time.current)
      end

      ask_registration
      expect(response).to have_http_status(:ok)
    end

    it "refuses a device that did not verify the person (RN-16-071)" do
      options = ask_registration
      json_post "/security/passkeys", credential: device.create(challenge: options["challenge"], user_verified: false)

      expect(response).to have_http_status(:unprocessable_content)
      expect(person.webauthn_credentials).to be_empty
    end

    it "refuses a credential made for another address" do
      options = ask_registration
      other = WebAuthn::FakeClient.new("https://outra.painel.catalysthr.com.br")
      json_post "/security/passkeys", credential: other.create(challenge: options["challenge"], user_verified: true)

      expect(response).to have_http_status(:unprocessable_content)
      expect(person.webauthn_credentials).to be_empty
    end

    it "uses a challenge only once" do
      options = ask_registration
      credential = device.create(challenge: options["challenge"], user_verified: true)
      json_post "/security/passkeys", credential: credential
      expect(response).to have_http_status(:ok)

      json_post "/security/passkeys", credential: credential
      expect(response).to have_http_status(:unprocessable_content)
      expect(person.webauthn_credentials.count).to eq(1)
    end

    it "keeps the challenge when another request rewrites the session at the same time" do
      options = ask_registration
      get "/notifications/unread-count"
      json_post "/security/passkeys", credential: device.create(challenge: options["challenge"], user_verified: true)

      expect(response).to have_http_status(:ok)
    end

    it "does not take a challenge of another ceremony" do
      options = ask_registration
      json_post "/sign-in/passkey", credential: device.create(challenge: options["challenge"], user_verified: true)

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "does not accept a challenge after 5 minutes" do
      options = ask_registration
      travel 6.minutes do
        json_post "/security/passkeys", credential: device.create(challenge: options["challenge"], user_verified: true)
      end

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["error"]).to eq("O tempo para cadastrar terminou. Tente de novo.")
    end

    it "answers a malformed credential as refused, without an error page" do
      ask_registration
      json_post "/security/passkeys", credential: { id: "x", response: { attestationObject: "não é base64" } }

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  it "asks for the MFA first when the profile requires it (RN-16-070)" do
    hr_user = create(:user, cpf: "98765432100", email: "hr@example.com")
    create(:membership, user: hr_user, organization: company, roles: %w[hr_admin])
    sign_in_with_password(login: "98765432100")

    ask_registration

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.parsed_body["error"]).to include("exige a verificação em duas etapas")
    get "/security"
    expect(response.body).not_to include("data-passkey-register")
  end

  describe "signing in (RN-16-071, RN-16-072)" do
    it "offers the button and the autofill on the sign-in page" do
      get "/sign-in"

      expect(response.body).to include("Entrar com digital ou rosto", 'autocomplete="username webauthn"')
    end

    it "lets an HR with mandatory MFA in, without the password or the code (CA-16-009)" do
      hr_user = enable_mfa(create(:user, cpf: "98765432100", email: "hr@example.com"))
      create(:membership, user: hr_user, organization: company, roles: %w[hr_admin])
        accept_legal_documents(hr_user, brand)
      sign_in_with_mfa("98765432100", hr_user)
      register
      delete "/sign-out"

      sign_in_with_passkey(user: hr_user)

      expect(response).to have_http_status(:ok)
      get "/employees"
      expect(response).to have_http_status(:ok)
      expect(AccessEvent.where(action: "sign_in", user: hr_user).order(:created_at).last.metadata).to include("method" => "passkey")
    end

    it "moves the counter and the last use on" do
      passkey = registered_passkey

      sign_in_with_passkey

      expect(passkey.reload.last_used_at).to be_present
      expect(passkey.sign_count).to be > 0
    end

    it "refuses an old counter, the sign of a cloned key" do
      passkey = registered_passkey
      passkey.update!(sign_count: 1_000_000_000)

      sign_in_with_passkey

      expect(response).to have_http_status(:unprocessable_content)
      expect(AccessEvent.find_by!(action: "sign_in_failed").metadata).to include("step" => "passkey")
      get "/security"
      expect(response).to redirect_to("/sign-in")
    end

    it "refuses a device that did not verify the person (RN-16-071)" do
      registered_passkey

      sign_in_with_passkey(verified: false)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["error"]).to eq("Não foi possível entrar com esta passkey. Tente de novo ou use a sua senha.")
    end

    it "refuses a handle that belongs to someone else" do
      registered_passkey
      other = create(:user, cpf: "98765432100", email: "outro@example.com", webauthn_handle: WebAuthn.generate_user_id)

      sign_in_with_passkey(user: other)

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "refuses a passkey that was removed" do
      registered_passkey.remove!

      sign_in_with_passkey

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "keeps a locked account out, without counting toward the lockout" do
      registered_passkey
      person.lock_access!

      sign_in_with_passkey
      expect(response).to have_http_status(:unprocessable_content)
      expect(AccessEvent.where(action: "sign_in_failed").last.metadata).to include("step" => "passkey")

      person.unlock_access!
      sign_in_with_passkey(verified: false)
      expect(person.reload.failed_attempts).to eq(0)
    end

    it "keeps a deactivated person out" do
      registered_passkey
      person.update!(status: "deactivated")

      sign_in_with_passkey

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "keeps out who lost the access to this brand (RN-02-004)" do
      registered_passkey
      membership.update!(status: "revoked")

      sign_in_with_passkey

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "serves only at its own address (RN-16-074)" do
      registered_passkey
      other_brand = create(:brand, owner: create(:company))
      other_brand.subdomains.create!(slug: "bravo")
      create(:membership, user: person, organization: other_brand.owner, roles: %w[employee])
      host! "bravo.painel.catalysthr.com.br"

      sign_in_with_passkey

      expect(response).to have_http_status(:unprocessable_content)
      get "/security"
      expect(response).to redirect_to("/sign-in")
    end

    it "uses a challenge only once" do
      registered_passkey
      json_post "/sign-in/passkey/challenge"
      credential = device.get(challenge: response.parsed_body["challenge"], user_verified: true)
      json_post "/sign-in/passkey", credential: credential
      expect(response).to have_http_status(:ok)
      delete "/sign-out"

      json_post "/sign-in/passkey", credential: credential
      expect(response).to have_http_status(:unprocessable_content)
    end

    it "answers a malformed credential as refused, without an error page" do
      json_post "/sign-in/passkey/challenge"
      json_post "/sign-in/passkey", credential: { id: "x", rawId: "%%%", response: {} }

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "at the admin host (RN-16-075)" do
    let(:origin) { "https://admin.catalysthr.com.br" }
    let!(:support) { enable_mfa(create(:user, cpf: "52998224725", email: "suporte@example.com", platform_role: "support")) }

    before { host! "admin.catalysthr.com.br" }

    it "registers with the admin's address and signs in with it" do
      sign_in_with_mfa("52998224725", support)

      expect(ask_registration["rp"]).to eq("name" => "CatalystHR", "id" => "admin.catalysthr.com.br")
      register
      expect(response).to have_http_status(:ok)
      delete "/sign-out"

      sign_in_with_passkey(user: support)

      expect(response).to have_http_status(:ok)
      get "/security"
      expect(response).to have_http_status(:ok)
    end
  end

  describe "confirming before sensitive data (RN-16-073)" do
    def confirm(client: device, verified: true, return_to: "/portal")
      json_post "/confirm-password/passkey/challenge"
      challenge = response.parsed_body["challenge"]
      json_post "/confirm-password/passkey", credential: client.get(challenge: challenge, user_verified: verified), return_to: return_to
    end

    it "takes the place of the password for the 5 minutes" do
      sign_in_with_password
      register

      confirm

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["redirect_to"]).to eq("/portal")
      expect(session[SensitiveAccess::CONFIRMATION_KEY]["user_id"]).to eq(person.id)
    end

    it "offers the button only to who has a passkey at this address" do
      sign_in_with_password
      get "/confirm-password", params: { return_to: "/portal" }
      expect(response.body).not_to include("data-passkey-confirm")

      register
      get "/confirm-password", params: { return_to: "/portal" }
      expect(response.body).to include("data-passkey-confirm", "Confirmar com digital ou rosto")
    end

    it "does not go to another host" do
      sign_in_with_password
      register

      confirm(return_to: "//evil.example")

      expect(response.parsed_body["redirect_to"]).to eq("/")
    end

    it "records a failure as the password does" do
      sign_in_with_password
      register

      confirm(verified: false)

      expect(response).to have_http_status(:unprocessable_content)
      expect(session[SensitiveAccess::CONFIRMATION_KEY]).to be_nil
      expect(AccessEvent.find_by!(action: "sensitive_confirmation_failed").user).to eq(person)
    end

    it "does not take someone else's passkey" do
      other_user = create(:user, cpf: "98765432100", email: "outro@example.com")
      create(:membership, user: other_user, organization: company, roles: %w[employee])
      passkey = registered_passkey
      passkey.update!(user: other_user)
      sign_in_with_password
      register(client: WebAuthn::FakeClient.new(origin))

      confirm(client: device)

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "needs a passkey at this address" do
      sign_in_with_password

      json_post "/confirm-password/passkey/challenge"

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "managing (RN-16-076)" do
    it "lists the name, the date and the last use, and removes" do
      passkey = registered_passkey
      sign_in_with_password

      get "/security"
      expect(response.body).to include("iPhone", "Cadastrada em", "último uso: nunca")

      delete "/security/passkeys/#{passkey.id}"
      expect(response).to redirect_to("/security#passkeys")
      expect(passkey.reload.removed_at).to be_present
      expect(AccessEvent.find_by!(action: "passkey_removed").user).to eq(person)
    end

    it "says where a passkey of another address serves" do
      person.webauthn_credentials.create!(rp_id: "bravo.painel.catalysthr.com.br", external_id: "x", public_key: "x", nickname: "Antiga")
      sign_in_with_password

      get "/security"

      expect(response.body).to include("Antiga", "Vale só em bravo.painel.catalysthr.com.br")
    end

    it "does not remove someone else's" do
      other = create(:user, cpf: "98765432100", email: "outro@example.com").webauthn_credentials
        .create!(rp_id: "aurora.painel.catalysthr.com.br", external_id: "x", public_key: "x", nickname: "Dele")
      sign_in_with_password

      delete "/security/passkeys/#{other.id}"

      expect(response).to have_http_status(:not_found)
      expect(other.reload.removed_at).to be_nil
    end

    it "survives a new password (P-16-20)" do
      passkey = registered_passkey
      sign_in_with_password

      patch "/security/password", params: { user: { current_password: password, password: "Outra#Senha2026", password_confirmation: "Outra#Senha2026" } }

      expect(person.reload.valid_password?("Outra#Senha2026")).to be(true)
      expect(passkey.reload.removed_at).to be_nil
    end

    it "does not go away when the person turns the MFA off" do
      passkey = registered_passkey
      enable_mfa(person)

      person.disable_mfa!

      expect(passkey.reload.removed_at).to be_nil
    end

    it "goes away with a reset of the MFA, of someone with the MFA off too" do
      passkey = registered_passkey
      admin = create(:user, cpf: "98765432100", email: "hr@example.com")

      Users::ResetMfa.call(user: person, by: admin, reason: "Celular perdido")

      expect(passkey.reload.removed_at).to be_present
      expect(AccessEvent.find_by!(action: "passkeys_removed")).to have_attributes(user: admin, subject: person,
        metadata: { "count" => 1, "reason" => "Celular perdido" })
    end
  end

  describe "the invite on the start (RN-16-022, D-647)" do
    it "is there until the person has a passkey at this address" do
      sign_in_with_password
      get "/portal"
      expect(response.body).to include("data-passkey-invite", "Entre com a digital ou o rosto")

      register
      get "/portal"
      expect(response.body).not_to include("data-passkey-invite")
    end
  end

  describe "with the flag off (P-20-11)" do
    before { Flipper.disable(FeatureFlags::PASSKEYS) }

    it "offers nothing and answers 404" do
      get "/sign-in"
      expect(response.body).not_to include("data-passkey-sign-in", "webauthn")

      json_post "/sign-in/passkey/challenge"
      expect(response).to have_http_status(:not_found)

      sign_in_with_password
      get "/security"
      expect(response.body).not_to include("Passkeys")
      get "/portal"
      expect(response.body).not_to include("data-passkey-invite")
      ask_registration
      expect(response).to have_http_status(:not_found)
      json_post "/confirm-password/passkey/challenge"
      expect(response).to have_http_status(:not_found)
    end

    it "still lets the reset remove what is there" do
      passkey = person.webauthn_credentials.create!(rp_id: "aurora.painel.catalysthr.com.br", external_id: "x", public_key: "x", nickname: "Dele")

      Users::ResetMfa.call(user: person, by: person)

      expect(passkey.reload.removed_at).to be_present
    end
  end
end
