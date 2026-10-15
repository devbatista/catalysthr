require "rails_helper"

# Spec 03, section 4.2: the company's users, managed by the HR administrator.
RSpec.describe "Company users", type: :request do
  include ActiveJob::TestHelper

  let(:company) { create(:company, name: "Metalúrgica Serra Azul") }
  let(:brand) { create(:brand, owner: company, commercial_name: "Serra Azul RH") }
  let!(:hr_admin) { enable_mfa(create(:user, name: "Carlos Mendes", cpf: "98765432100")) }

  before do
    create(:membership, user: hr_admin, organization: company, roles: %w[hr_admin])
    brand.subdomains.create!(slug: "serraazul")
    Flipper.enable(FeatureFlags::SIGN_IN)
    publish_platform_legal_documents
    accept_legal_documents(hr_admin, brand)
    host! "serraazul.painel.catalysthr.com.br"
    sign_in_with_mfa("98765432100", hr_admin)
  end

  def invite(**overrides)
    post "/users", params: { invitation: { name: "Joana Prado", cpf: "11144477735", email: "joana@example.com",
      roles: %w[hr_analyst], enabled_modules: %w[admissao], channels: %w[email link] }.merge(overrides) }
  end

  it "invites an HR analyst with modules, by e-mail and by link with QR code" do
    perform_enqueued_jobs { invite }

    expect(response).to have_http_status(:ok)
    expect(response.headers["Cache-Control"]).to eq("no-store")
    expect(response.body).to include("Convite criado para Joana Prado", "http://serraazul.painel.catalysthr.com.br/invitation?token=", "<svg")
    membership = Membership.find_by!(user: User.find_by!(cpf: "11144477735"))
    expect(membership).to have_attributes(organization: company, roles: %w[hr_analyst], enabled_modules: %w[admissao], status: "invited")
    expect(ActionMailer::Base.deliveries.last.to).to eq([ "joana@example.com" ])
  end

  it "only gives the roles of this version: HR and managers" do
    invite(roles: %w[hr_admin employee client_manager])

    expect(Membership.find_by!(user: User.find_by!(cpf: "11144477735")).roles).to eq(%w[hr_admin])
  end

  it "shows the errors of an invalid invitation" do
    invite(cpf: "123", roles: [])

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("CPF não é um CPF válido")
  end

  it "lists only this company's users" do
    create(:membership, organization: company, roles: %w[manager], user: create(:user, name: "Ana Ribeiro"))
    create(:membership, organization: create(:company), user: create(:user, name: "Pessoa de Fora"))

    get "/users"

    expect(response.body).to include("Carlos Mendes", "Ana Ribeiro")
    expect(response.body).not_to include("Pessoa de Fora")
  end

  it "answers 404 for another company's user and 403 for a denied action (RN-01-013, RN-03-006)" do
    other = create(:membership, organization: create(:company))
    own = Membership.find_by!(user: hr_admin)

    get "/users/#{other.id}"
    expect(response).to have_http_status(:not_found)

    patch "/users/#{own.id}", params: { membership: { roles: %w[manager] } }
    expect(response).to have_http_status(:forbidden)
  end

  it "changes the roles, which ends the person's sessions (RN-02-063)" do
    member = create(:membership, organization: company, roles: %w[hr_analyst])
    UserSession.start!(user: member.user, area: "panel", brand: brand, ip: "10.0.0.1", user_agent: "Outro")

    patch "/users/#{member.id}", params: { membership: { roles: %w[manager] } }

    expect(response).to redirect_to("/users/#{member.id}")
    expect(member.reload.roles).to eq(%w[manager])
    expect(member.user.user_sessions.active).to be_empty
  end

  it "removes the access" do
    member = create(:membership, organization: company, roles: %w[manager])

    delete "/users/#{member.id}"

    expect(response).to redirect_to("/users")
    expect(member.reload).to be_revoked
  end

  it "resends an invitation with a new link (CA-02-002)" do
    invite(channels: %w[link])
    membership = Membership.find_by!(user: User.find_by!(cpf: "11144477735"))
    first_digest = membership.invitation_token_digest

    post "/users/#{membership.id}/resend-invitation", params: { channels: %w[link] }

    expect(response.body).to include("/invitation?token=")
    expect(membership.reload.invitation_token_digest).not_to eq(first_digest)
  end

  describe "MFA reset and contact correction (RN-02-044, P-02-17, D-582)" do
    let!(:analyst) { create(:membership, organization: company, roles: %w[hr_analyst], user: enable_mfa(create(:user, email: "ana@example.com"))) }

    it "resets the MFA, ends the sessions and tells the person" do
      UserSession.start!(user: analyst.user, area: "panel", brand: brand, ip: "10.0.0.1", user_agent: "Outro")

      perform_enqueued_jobs { post "/users/#{analyst.id}/reset-mfa" }

      expect(analyst.user.reload).not_to be_mfa_enabled
      expect(analyst.user.user_sessions.active).to be_empty
      expect(AccessEvent.find_by!(action: "mfa_reset")).to have_attributes(user: hr_admin, subject: analyst.user, company: company)
      mail = ActionMailer::Base.deliveries.last
      expect(mail.to).to eq([ "ana@example.com" ])
      expect(mail.subject).to eq("Verificação em duas etapas redefinida em Serra Azul RH")
    end

    it "corrects the e-mail and tells the old address, without the new one" do
      perform_enqueued_jobs { patch "/users/#{analyst.id}/contact", params: { email: "ana.nova@example.com", mobile_phone: "" } }

      expect(analyst.user.reload.email).to eq("ana.nova@example.com")
      mail = ActionMailer::Base.deliveries.last
      expect(mail.to).to eq([ "ana@example.com" ])
      expect(mail.text_part.body.to_s).not_to include("ana.nova@example.com")
      event = AccessEvent.find_by!(action: "contact_corrected")
      expect(event.metadata).to eq("fields" => [ "email" ])
      expect(analyst.user.versions.last.object_changes["email"]).to eq([ "ana@example.com", "ana.nova@example.com" ])
    end

    it "leaves both to the support when the person has access elsewhere" do
      create(:membership, user: analyst.user, organization: create(:company))

      get "/users/#{analyst.id}"
      expect(response.body).to include("são feitas pelo suporte")

      post "/users/#{analyst.id}/reset-mfa"
      expect(response).to have_http_status(:forbidden)
      patch "/users/#{analyst.id}/contact", params: { email: "invasor@example.com" }
      expect(response).to have_http_status(:forbidden)
      expect(analyst.user.reload.email).to eq("ana@example.com")
    end
  end

  it "keeps the users page closed to an HR analyst" do
    delete "/sign-out"
    analyst = enable_mfa(create(:user, cpf: "11144477735"))
    create(:membership, user: analyst, organization: company, roles: %w[hr_analyst])
    accept_legal_documents(analyst, brand)
    sign_in_with_mfa("11144477735", analyst)

    get "/users"
    expect(response).to have_http_status(:forbidden)
  end
end
