require "rails_helper"

# Spec 02: sign-in, lockout, recovery and unlock, on a brand's subdomain and at the
# admin host.
RSpec.describe "Sign-in", type: :request do
  include ActiveJob::TestHelper

  let(:partner) { create(:partner) }
  let(:brand) do
    create(:brand, owner: partner, commercial_name: "Aurora RH", login_welcome_text: "Bem-vindo ao portal de RH da Aurora.",
      support_email: "suporte@aurora.example")
  end
  let(:company) { create(:company, partner: partner) }
  let!(:user) { create(:user, name: "Maria Souza", cpf: "12345678909", email: "maria@example.com") }
  let!(:membership) { create(:membership, user: user, organization: company) }
  let(:invalid_message) { "CPF, e-mail ou senha inválidos." }

  before do
    brand.subdomains.create!(slug: "aurora")
    Flipper.enable(FeatureFlags::SIGN_IN)
    host! "aurora.painel.catalysthr.com.br"
  end

  def sign_in_with(login, password = "Catalyst#2026")
    post "/entrar", params: { user: { login: login, password: password } }
  end

  def signed_in?
    get "/"
    response.status == 200 && response.body.include?("Olá, Maria.")
  end

  def last_link
    ActionMailer::Base.deliveries.last.text_part.body.to_s[%r{https?://\S+}]
  end

  it "keeps everything closed while the flag is off (P-20-11)" do
    Flipper.disable(FeatureFlags::SIGN_IN)

    get "/entrar"
    expect(response).to have_http_status(:not_found)

    get "/"
    expect(response.body).to include("O acesso será liberado em breve.")
  end

  it "shows the sign-in page with the brand (CA-01-001)" do
    get "/"
    expect(response).to redirect_to("/entrar")

    get "/entrar"
    expect(response.body).to include("Aurora RH", "Bem-vindo ao portal de RH da Aurora.", "CPF ou e-mail", "suporte@aurora.example")
  end

  it "renders every access page in Portuguese, in the panel and in the admin area" do
    [ "aurora.painel.catalysthr.com.br", "admin.catalysthr.com.br" ].each do |host|
      host! host
      [ "/entrar", "/senha/solicitar", "/desbloqueio/solicitar", "/senha/redefinir?reset_password_token=x" ].each do |path|
        get path
        expect(response).to have_http_status(:ok), "#{host}#{path}"
        expect(response.body).not_to include("translation_missing", "Translation missing"), "#{host}#{path}"
      end
    end
  end

  it "signs in with the CPF with or without the mask, and with the e-mail (CA-02-003)" do
    [ "123.456.789-09", "12345678909", "Maria@Example.com" ].each do |login|
      sign_in_with(login)
      expect(response).to redirect_to("/"), login
      expect(signed_in?).to be(true), login

      delete "/sair"
      expect(signed_in?).to be(false)
    end
  end

  it "answers a person of another brand as invalid credentials (RN-01-002, P-01-03)" do
    sign_in_with("12345678909", "Errada#2026")
    wrong_password = response.body[/CPF, e-mail ou senha inválidos[^<]*/]

    other = create(:user, cpf: "98765432100", password: "Catalyst#2026")
    create(:membership, user: other, organization: create(:company))
    sign_in_with("98765432100")

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body[/CPF, e-mail ou senha inválidos[^<]*/]).to eq(wrong_password)
    expect(signed_in?).to be(false)
  end

  it "does not let the CatalystHR team sign in on a brand's subdomain (RN-02-004)" do
    user.update!(platform_role: "support")

    sign_in_with("12345678909")

    expect(response.body).to include(invalid_message)
    expect(signed_in?).to be(false)
  end

  describe "admin host (P-02-06)" do
    before { host! "admin.catalysthr.com.br" }

    it "lets only the CatalystHR team in" do
      sign_in_with("12345678909")
      expect(response.body).to include(invalid_message)

      staff = create(:user, :platform, name: "Paulo Lima", cpf: "52998224725")
      sign_in_with("529.982.247-25")
      expect(response).to redirect_to("/")

      get "/"
      expect(response.body).to include("Olá, Paulo.")
    end
  end

  describe "lockout (RN-02-031)" do
    it "keeps the account locked after 5 wrong attempts until the unlock link (CA-02-005)" do
      perform_enqueued_jobs do
        5.times { sign_in_with("12345678909", "Errada#2026") }
      end
      expect(user.reload).to be_access_locked

      sign_in_with("12345678909")
      expect(response.body).to include(invalid_message)
      expect(signed_in?).to be(false)

      mail = ActionMailer::Base.deliveries.last
      expect(mail.subject).to eq("Desbloqueio do acesso")
      expect(mail[:from].to_s).to eq("Aurora RH <nao-responda@catalysthr.com.br>")
      expect(mail.reply_to).to eq([ "suporte@aurora.example" ])
      expect(last_link).to start_with("http://aurora.painel.catalysthr.com.br/desbloqueio?unlock_token=")

      get last_link
      expect(user.reload).not_to be_access_locked

      sign_in_with("12345678909")
      expect(signed_in?).to be(true)
    end

    it "sends the unlock link again on request, with the same answer for anyone" do
      perform_enqueued_jobs do
        5.times { sign_in_with("12345678909", "Errada#2026") }
        ActionMailer::Base.deliveries.clear

        post "/desbloqueio", params: { user: { login: "12345678909" } }
        known = flash[:notice]
        post "/desbloqueio", params: { user: { login: "11144477735" } }

        expect(flash[:notice]).to eq(known)
      end

      expect(ActionMailer::Base.deliveries.size).to eq(1)
    end
  end

  describe "recovery by e-mail (RN-02-033)" do
    it "answers the same for a CPF that does not exist (CA-02-016)" do
      perform_enqueued_jobs do
        post "/senha", params: { user: { login: "11144477735" } }
        unknown = flash[:notice]
        post "/senha", params: { user: { login: "123.456.789-09" } }

        expect(flash[:notice]).to eq(unknown)
        expect(unknown).to eq("Se houver cadastro, enviamos as instruções.")
      end

      expect(ActionMailer::Base.deliveries.size).to eq(1)
    end

    it "creates a new password through the link, within the rules (CA-02-004)" do
      perform_enqueued_jobs { post "/senha", params: { user: { login: "maria@example.com" } } }
      expect(last_link).to start_with("http://aurora.painel.catalysthr.com.br/senha/redefinir?reset_password_token=")
      token = Rack::Utils.parse_query(URI(last_link).query)["reset_password_token"]

      put "/senha", params: { user: { reset_password_token: token, password: "catalyst1", password_confirmation: "catalyst1" } }
      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("precisa ter pelo menos uma letra maiúscula")

      put "/senha", params: { user: { reset_password_token: token, password: "Nova#Senha2026", password_confirmation: "Nova#Senha2026" } }
      expect(response).to redirect_to("/entrar")

      sign_in_with("12345678909", "Nova#Senha2026")
      expect(signed_in?).to be(true)
    end

    it "expires the link after 2 hours (P-02-16)" do
      perform_enqueued_jobs { post "/senha", params: { user: { login: "maria@example.com" } } }
      token = Rack::Utils.parse_query(URI(last_link).query)["reset_password_token"]

      travel 2.hours + 1.minute do
        put "/senha", params: { user: { reset_password_token: token, password: "Nova#Senha2026", password_confirmation: "Nova#Senha2026" } }
        expect(response).to have_http_status(:unprocessable_content)
      end
    end

    it "sends nothing to a person without e-mail; the WhatsApp code comes with Twilio" do
      user.update!(email: nil, mobile_phone: "11987654321")

      perform_enqueued_jobs { post "/senha", params: { user: { login: "12345678909" } } }

      expect(flash[:notice]).to eq("Se houver cadastro, enviamos as instruções.")
      expect(ActionMailer::Base.deliveries).to be_empty
    end
  end

  it "ends the session at the next request once the membership is suspended (RN-02-063)" do
    sign_in_with("12345678909")
    expect(signed_in?).to be(true)

    membership.update!(status: "suspended")

    get "/"
    expect(response).to redirect_to("/entrar")
    expect(signed_in?).to be(false)
  end

  it "lets a read-only membership sign in (D-090)" do
    membership.update!(status: "read_only")

    sign_in_with("12345678909")
    expect(signed_in?).to be(true)
  end
end
