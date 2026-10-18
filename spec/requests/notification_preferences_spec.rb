require "rails_helper"

# Spec 15, RN-15-020 to RN-15-023 (CA-15-007, D-607, D-609): the company's default
# channels and each person's, and the support releasing an e-mail that bounced.
RSpec.describe "Notification preferences", type: :request do
  include ActiveJob::TestHelper

  let(:company) { create(:company, name: "Metalúrgica Serra Azul") }
  let(:brand) { create(:brand, owner: company, commercial_name: "Serra Azul RH") }
  let!(:hr_admin) { enable_mfa(create(:user, name: "Juliana Ribeiro", cpf: "98765432100", email: "juliana@example.com")) }
  let!(:membership) { create(:membership, user: hr_admin, organization: company, roles: %w[hr_admin]) }

  before do
    brand.subdomains.create!(slug: "serraazul")
    Flipper.enable(FeatureFlags::SIGN_IN)
    publish_platform_legal_documents
    host! "serraazul.painel.catalysthr.com.br"
  end

  def sign_in_as_hr
    accept_legal_documents(hr_admin, brand)
    sign_in_with_mfa("98765432100", hr_admin)
  end

  def revisions_notice(user, member)
    Notifications.notify!("employments.revisions_effective", user: user, membership: member, path: "/employees", count: 1, list: "Ana")
  end

  it "lets the person turn off an optional e-mail, but keeps the mandatory one (RN-15-021, RN-15-022, CA-15-007)" do
    sign_in_as_hr

    get "/notification-preferences/edit"
    expect(response.body).to include("Minhas notificações", "Metalúrgica Serra Azul", "Revisões que entram em vigor",
      "Verificação em duas etapas redefinida", "Obrigatório")

    patch "/notification-preferences", params: { preferences: { membership.id => {
      "employments.revisions_effective" => [ "" ], "security.mfa_reset" => [ "", "email" ] } } }
    expect(response).to redirect_to("/notification-preferences/edit")
    expect(revisions_notice(hr_admin, membership).deliveries).to be_empty

    patch "/notification-preferences", params: { preferences: { membership.id => { "security.mfa_reset" => [ "" ] } } }
    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("precisam incluir o e-mail, porque o aviso é obrigatório")
    expect(NotificationPreference.find_by(membership: membership, notification_type: "security.mfa_reset").channels).to eq(%w[email])
  end

  it "uses the company's default when the person has not chosen (RN-15-020)" do
    analyst = create(:user, email: "paula@example.com")
    analyst_membership = create(:membership, user: analyst, organization: company, roles: %w[hr_analyst])
    sign_in_as_hr

    get "/settings/notifications/edit"
    expect(response.body).to include("Canais dos avisos", "E-mail de alguém voltou")
    patch "/settings/notifications", params: { settings: { "employments.revisions_effective" => [ "" ], "security.mfa_reset" => [ "", "email" ] } }
    expect(response).to redirect_to("/settings/notifications/edit")

    expect(revisions_notice(analyst, analyst_membership).deliveries).to be_empty
    NotificationPreference.create!(membership: analyst_membership, notification_type: "employments.revisions_effective", channels: %w[email])
    expect(revisions_notice(analyst, analyst_membership).deliveries.size).to eq(1)
  end

  it "tells the person when the important notices have no way out of the bell (RN-15-023)" do
    hr_admin.update!(email_status: "bounced", email_status_at: Time.current)
    sign_in_as_hr

    get "/notification-preferences/edit"
    expect(response.body).to include("O seu e-mail voltou e foi marcado como inválido")
  end

  it "links the preferences from the notice's e-mail (RN-15-002)" do
    perform_enqueued_jobs do
      Notifications.notify!("security.mfa_reset", user: hr_admin, membership: membership, path: "/security", brand_name: "Serra Azul RH")
    end

    expect(ActionMailer::Base.deliveries.sole.text_part.body.to_s)
      .to include("Minhas notificações: http://serraazul.painel.catalysthr.com.br/notification-preferences/edit")
  end

  describe "the support releasing an e-mail that bounced (D-609)" do
    let!(:support) { enable_mfa(create(:user, name: "Sofia Suporte", cpf: "52998224725", platform_role: "support")) }

    it "takes the address off SES's suppression list and the mark away, with the reason" do
      hr_admin.update!(email_status: "bounced", email_status_at: Time.current)
      client = stub_ses(delete_suppressed_destination: {})
      host! "admin.catalysthr.com.br"
      sign_in_with_mfa("52998224725", support)

      get "/users", params: { cpf: "98765432100" }
      expect(response.body).to include("Voltou em", "Liberar o e-mail")

      post "/users/#{hr_admin.id}/release-email", params: { reason: "Chamado 77" }
      expect(response).to redirect_to("/users?cpf=98765432100")
      expect(hr_admin.reload).to be_email_valid
      expect(client.api_requests.map { |request| request[:operation_name] }).to include(:delete_suppressed_destination)
      expect(AccessEvent.find_by!(action: "email_released").metadata).to eq("reason" => "Chamado 77")
    end
  end
end
