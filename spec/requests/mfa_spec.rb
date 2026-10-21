require "rails_helper"

# Spec 02: MFA (RN-02-040 to RN-02-043, D-580).
RSpec.describe "MFA", type: :request do
  include ActiveJob::TestHelper

  let(:partner) { create(:partner) }
  let(:brand) { create(:brand, owner: partner) }
  let(:company) { create(:company, partner: partner) }
  let!(:user) { create(:user, cpf: "12345678909", email: "maria@example.com") }

  before do
    brand.subdomains.create!(slug: "aurora")
    Flipper.enable(FeatureFlags::SIGN_IN)
    publish_platform_legal_documents
    host! "aurora.painel.catalysthr.com.br"
  end

  def sign_in_with(password = "Catalyst#2026")
    post "/sign-in", params: { user: { login: "12345678909", password: password } }
  end

  def submit_code(code, remember: false)
    post "/sign-in/code", params: { otp_code: code, remember_device: remember ? "1" : "0" }
  end

  def set_up_mfa
    get "/security/mfa/new"
    secret = session[Account::MfaController::SECRET_KEY]
    post "/security/mfa", params: { otp_code: ROTP::TOTP.new(secret).now }
  end

  describe "first access with a role that requires MFA" do
    it "does not let an HR analyst go on without the authenticator (CA-02-006)" do
      invitation = Invitations::Create.call(organization: company, roles: %w[hr_analyst], channels: %w[link],
        invited_by: user, name: "Joana Prado", cpf: "11144477735", email: "joana@example.com")
      patch "/invitation", params: { token: invitation.token, password: "Joana#2026", password_confirmation: "Joana#2026" }
      post "/first-access/terms", params: { accept: { terms: "1", privacy: "1" } }

      get "/"
      expect(response).to redirect_to("/security/mfa/new")

      get "/security/mfa/new"
      expect(response.body).to include("<svg", "O seu perfil exige a verificação em duas etapas")
      expect(response.headers["Cache-Control"]).to eq("no-store")

      post "/security/mfa", params: { otp_code: wrong_otp(session[Account::MfaController::SECRET_KEY]) }
      expect(response).to have_http_status(:unprocessable_content)

      set_up_mfa
      expect(response.body).to include("Códigos de recuperação")
      expect(response.body.scan(%r{<li>[0-9a-f]{10}</li>}).size).to eq(10)

      get "/"
      expect(response).to have_http_status(:ok)
    end

    it "takes the same form sent twice to the security page, not to an invalid code" do
      membership = create(:membership, user: user, organization: company, roles: %w[hr_analyst])
      sign_in_with
      get "/security/mfa/new"
      code = ROTP::TOTP.new(session[Account::MfaController::SECRET_KEY]).now

      post "/security/mfa", params: { otp_code: code }
      expect(response.body).to include("Códigos de recuperação")
      post "/security/mfa", params: { otp_code: code }

      expect(response).to redirect_to("/security")
      follow_redirect!
      expect(response.body).to include("já está ativa", "gere novos abaixo")
      expect(membership.user.reload).to be_mfa_enabled
    end

    it "requires it from the client's manager too (CA-02-017, P-02-39)" do
      create(:membership, user: user, organization: company, roles: %w[client_manager])
      accept_legal_documents(user, brand)
      sign_in_with

      get "/"
      expect(response).to redirect_to("/security/mfa/new")
    end

    it "requires it in every organization once one role requires it (RN-02-041)" do
      create(:membership, user: user, organization: company, roles: %w[manager])
      other_company = create(:company, partner: partner)
      create(:membership, user: user, organization: other_company, roles: %w[hr_admin])

      expect(user.mfa_required?).to be(true)
    end
  end

  describe "sign-in with MFA" do
    before do
      create(:membership, user: user, organization: company, roles: %w[hr_admin])
      accept_legal_documents(user, brand)
      enable_mfa(user)
    end

    it "asks for the code after the right password" do
      sign_in_with
      expect(response).to redirect_to("/sign-in/code")

      get "/"
      expect(response).to redirect_to("/sign-in")

      submit_code(user.reload.current_otp)
      expect(response).to redirect_to("/")
      get "/"
      expect(response).to have_http_status(:ok)
    end

    it "answers a wrong password the same way, without asking for the code" do
      sign_in_with("Errada#2026")

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("CPF, e-mail ou senha inválidos.")
    end

    it "accepts each recovery code once" do
      codes = user.regenerate_recovery_codes!

      sign_in_with
      submit_code(codes.first)
      expect(response).to redirect_to("/")
      delete "/sign-out"

      sign_in_with
      submit_code(codes.first)
      expect(response).to have_http_status(:unprocessable_content)
    end

    it "locks the account after 5 wrong attempts, adding passwords and codes (D-580)" do
      perform_enqueued_jobs do
        3.times { sign_in_with("Errada#2026") }
        sign_in_with
        2.times { submit_code(wrong_otp(user.reload.otp_secret)) }
      end

      expect(user.reload).to be_access_locked
      expect(response).to redirect_to("/sign-in")
      expect(ActionMailer::Base.deliveries.last.subject).to eq("Desbloqueio do acesso")
    end

    it "gives 5 minutes to type the code" do
      sign_in_with

      travel 6.minutes do
        submit_code(user.reload.current_otp)
        expect(response).to redirect_to("/sign-in")
        expect(flash[:alert]).to include("O tempo para digitar o código terminou")
      end
    end

    it "skips the code on a remembered device until the password changes (CA-02-007)" do
      sign_in_with
      submit_code(user.reload.current_otp, remember: true)
      delete "/sign-out"

      travel 29.days do
        sign_in_with
        expect(response).to redirect_to("/")

        patch "/security/password", params: { user: { current_password: "Catalyst#2026", password: "Nova#Senha2026",
          password_confirmation: "Nova#Senha2026" } }
        delete "/sign-out"

        sign_in_with("Nova#Senha2026")
        expect(response).to redirect_to("/sign-in/code")
      end
    end

    it "asks for the code again after the 30 days" do
      sign_in_with
      submit_code(user.reload.current_otp, remember: true)
      delete "/sign-out"

      travel 31.days do
        sign_in_with
        expect(response).to redirect_to("/sign-in/code")
      end
    end
  end

  describe "security page" do
    before { accept_legal_documents(user, brand) }

    it "lets a person whose MFA is optional turn it off with the password (RN-02-040)" do
      create(:membership, user: user, organization: company, roles: %w[manager])
      sign_in_with
      set_up_mfa

      delete "/security/mfa", params: { current_password: "Errada#2026" }
      expect(user.reload).to be_mfa_enabled

      delete "/security/mfa", params: { current_password: "Catalyst#2026" }
      expect(user.reload).not_to be_mfa_enabled
      expect(user.otp_secret).to be_nil
    end

    it "does not let a required MFA be turned off" do
      create(:membership, user: user, organization: company, roles: %w[hr_admin])
      enable_mfa(user)
      sign_in_with
      submit_code(user.reload.current_otp)

      delete "/security/mfa", params: { current_password: "Catalyst#2026" }

      expect(flash[:alert]).to eq("O seu perfil exige a verificação em duas etapas.")
      expect(user.reload).to be_mfa_enabled
    end

    it "replaces the recovery codes (P-02-20)" do
      create(:membership, user: user, organization: company, roles: %w[manager])
      sign_in_with
      set_up_mfa
      old_codes = response.body.scan(%r{<li>([0-9a-f]{10})</li>}).flatten

      post "/security/recovery-codes", params: { current_password: "Catalyst#2026" }
      new_codes = response.body.scan(%r{<li>([0-9a-f]{10})</li>}).flatten

      expect(new_codes.size).to eq(10)
      expect(user.reload.invalidate_otp_backup_code!(old_codes.first)).to be(false)
      expect(user.invalidate_otp_backup_code!(new_codes.first)).to be(true)
    end
  end

  it "keeps the authenticator secret encrypted in the database (D-086)" do
    enable_mfa(user)

    stored = User.connection.select_value("SELECT otp_secret FROM users WHERE id = '#{user.id}'")
    expect(stored).not_to include(user.otp_secret)
  end
end
