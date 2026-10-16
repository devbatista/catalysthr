require "rails_helper"

# D-582, RN-02-044 and P-02-17: the support corrects the contact or resets the MFA of a
# client's user who also reaches another organization.
RSpec.describe "Admin: users' contact and MFA", type: :request do
  include ActiveJob::TestHelper

  let!(:support) { enable_mfa(create(:user, cpf: "52998224725", platform_role: "support")) }
  let!(:person) { enable_mfa(create(:user, name: "Rita Duas Empresas", cpf: "98765432100", email: "rita@antigo.example")) }

  before do
    create(:membership, user: person, organization: create(:company, name: "Padaria Pão Quente"), roles: %w[hr_admin])
    create(:membership, user: person, organization: create(:company, name: "Transportes Rápidos"), roles: %w[hr_analyst])
    Flipper.enable(FeatureFlags::SIGN_IN)
    host! "admin.catalysthr.com.br"
    sign_in_with_mfa("52998224725", support)
  end

  it "finds the person by CPF with their accesses" do
    get "/users", params: { cpf: "987.654.321-00" }

    expect(response.body).to include("Rita Duas Empresas", "Padaria Pão Quente", "Transportes Rápidos",
      "Corrigir o contato", "Redefinir a verificação em duas etapas")
  end

  it "corrects the contact with a reason, telling the old e-mail on behalf of CatalystHR" do
    perform_enqueued_jobs do
      patch "/users/#{person.id}/contact", params: { email: "rita@novo.example", reason: "Chamado 900" }
    end

    expect(response).to redirect_to("/users?cpf=98765432100")
    expect(person.reload.email).to eq("rita@novo.example")
    expect(AccessEvent.find_by!(action: "contact_corrected")).to have_attributes(user: support, subject: person,
      metadata: { "fields" => [ "email" ], "reason" => "Chamado 900" })
    mail = ActionMailer::Base.deliveries.last
    expect(mail.to).to eq([ "rita@antigo.example" ])
    expect(mail[:from].display_names).to eq([ "CatalystHR" ])
  end

  it "resets the MFA with a reason, ending the sessions" do
    UserSession.start!(user: person, area: "panel", brand: nil, ip: "10.0.0.1", user_agent: "Outro")

    post "/users/#{person.id}/reset-mfa", params: { reason: "Chamado 901" }

    expect(person.reload.mfa_enabled?).to be(false)
    expect(person.user_sessions.active).to be_empty
    expect(AccessEvent.find_by!(action: "mfa_reset").metadata).to eq("reason" => "Chamado 901")
  end

  it "requires the reason" do
    post "/users/#{person.id}/reset-mfa", params: { reason: " " }

    expect(response).to redirect_to("/users?cpf=98765432100")
    expect(person.reload.mfa_enabled?).to be(true)
  end

  it "never reaches someone of the CatalystHR team" do
    superadmin = create(:user, cpf: "11144477735", platform_role: "superadmin")

    get "/users", params: { cpf: "111.444.777-35" }
    expect(response.body).to include("Nenhum usuário de cliente com este CPF")

    post "/users/#{superadmin.id}/reset-mfa", params: { reason: "x" }
    expect(response).to have_http_status(:not_found)
  end
end
