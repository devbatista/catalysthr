require "rails_helper"

# Spec 02: sessions on the server (D-576), inactivity (RN-02-050, RN-02-051) and the
# list of open sessions (RN-02-053).
RSpec.describe "Sessions", type: :request do
  include ActiveJob::TestHelper

  let(:partner) { create(:partner) }
  let(:brand) { create(:brand, owner: partner) }
  let(:company) { create(:company, partner: partner) }
  let!(:user) { create(:user, name: "Maria Souza", cpf: "12345678909", email: "maria@example.com") }
  let(:roles) { %w[manager employee] }

  before do
    create(:membership, user: user, organization: company, roles: roles)
    brand.subdomains.create!(slug: "aurora")
    Flipper.enable(FeatureFlags::SIGN_IN)
    publish_platform_legal_documents
    accept_legal_documents(user, brand)
    host! "aurora.painel.catalysthr.com.br"
  end

  def sign_in_here(password = "Catalyst#2026")
    post "/entrar", params: { user: { login: "12345678909", password: password } }
  end

  def signed_in?
    get "/"
    response.status == 200
  end

  it "records the session with the brand, the IP and the browser" do
    post "/entrar", params: { user: { login: "12345678909", password: "Catalyst#2026" } },
      headers: { "User-Agent" => "Navegador de teste" }

    session_record = user.user_sessions.sole
    expect(session_record).to have_attributes(area: "panel", brand: brand, ip: "127.0.0.1", user_agent: "Navegador de teste")
    expect(session_record.token_digest).to be_present
  end

  context "with a manager who is also an employee" do
    it "ends the session after 30 minutes without use, also in the portal (CA-02-008, P-02-24)" do
      sign_in_here

      travel 29.minutes do
        expect(signed_in?).to be(true)
      end

      travel 29.minutes + 31.minutes do
        get "/"
        expect(flash[:alert]).to eq("Sua sessão terminou. Entre de novo.")
        expect(signed_in?).to be(false)
      end
    end
  end

  context "with someone who is only an employee" do
    let(:roles) { %w[employee] }

    it "keeps the session for 14 days without use (RN-02-050)" do
      sign_in_here

      travel 10.days do
        expect(signed_in?).to be(true)
      end

      travel 10.days + 15.days do
        expect(signed_in?).to be(false)
      end
    end
  end

  it "closes the session at sign-out" do
    sign_in_here
    delete "/sair"

    expect(user.user_sessions.sole.revoked_reason).to eq("sign_out")
  end

  describe "list of open sessions" do
    it "ends another session, which signs out at its next request (RN-02-053)" do
      other = open_session
      other.host! "aurora.painel.catalysthr.com.br"
      other.post "/entrar", params: { user: { login: "12345678909", password: "Catalyst#2026" } }

      sign_in_here
      get "/seguranca"
      expect(response.body).to include("Esta sessão", "Encerrar")

      other_session = user.user_sessions.order(:created_at).first
      delete "/seguranca/sessoes/#{other_session.id}"
      expect(other_session.reload.revoked_reason).to eq("ended_by_user")

      # The redirect matchers read the main session, so the other one is checked by hand.
      other.get "/"
      expect(other.flash[:alert]).to eq("Sua sessão terminou. Entre de novo.")
      other.follow_redirect!
      expect(other.response.location).to eq("http://aurora.painel.catalysthr.com.br/entrar")
      expect(signed_in?).to be(true)
    end

    it "does not end someone else's session" do
      stranger = create(:user)
      stranger_session = UserSession.find_active(UserSession.start!(user: stranger, area: "panel", brand: brand,
        ip: "10.0.0.1", user_agent: "Outro"))
      sign_in_here

      delete "/seguranca/sessoes/#{stranger_session.id}"

      expect(response).to have_http_status(:not_found)
      expect(stranger_session.reload.revoked_at).to be_nil
    end
  end

  it "ends the other sessions and keeps this one when the password changes (RN-02-053)" do
    other = open_session
    other.host! "aurora.painel.catalysthr.com.br"
    other.post "/entrar", params: { user: { login: "12345678909", password: "Catalyst#2026" } }
    sign_in_here

    patch "/seguranca/senha", params: { user: { current_password: "Catalyst#2026", password: "Nova#Senha2026",
      password_confirmation: "Nova#Senha2026" } }
    expect(response).to redirect_to("/seguranca")

    expect(signed_in?).to be(true)
    other.get "/"
    expect(other.response.location).to eq("http://aurora.painel.catalysthr.com.br/entrar")
    expect(user.user_sessions.active.count).to eq(1)
  end

  it "refuses the password change with a wrong current password" do
    sign_in_here

    patch "/seguranca/senha", params: { user: { current_password: "Errada#2026", password: "Nova#Senha2026",
      password_confirmation: "Nova#Senha2026" } }

    expect(response).to have_http_status(:unprocessable_content)
    expect(user.reload.valid_password?("Catalyst#2026")).to be(true)
  end

  it "ends every session after a password reset by e-mail" do
    sign_in_here
    delete "/sair"
    other = open_session
    other.host! "aurora.painel.catalysthr.com.br"
    other.post "/entrar", params: { user: { login: "12345678909", password: "Catalyst#2026" } }

    perform_enqueued_jobs { post "/senha", params: { user: { login: "maria@example.com" } } }
    token = Rack::Utils.parse_query(URI(ActionMailer::Base.deliveries.last.text_part.body.to_s[%r{https?://\S+}]).query)["reset_password_token"]
    put "/senha", params: { user: { reset_password_token: token, password: "Nova#Senha2026", password_confirmation: "Nova#Senha2026" } }

    expect(user.user_sessions.active).to be_empty
  end
end
