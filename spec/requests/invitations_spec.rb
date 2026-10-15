require "rails_helper"

# Spec 02: invitation link and first access (RN-02-011 to RN-02-014).
RSpec.describe "Invitation", type: :request do
  let(:partner) { create(:partner) }
  let(:brand) { create(:brand, owner: partner, commercial_name: "Aurora RH") }
  let(:company) { create(:company, partner: partner) }
  let(:inviter) { create(:user) }

  before do
    brand.subdomains.create!(slug: "aurora")
    Flipper.enable(FeatureFlags::SIGN_IN)
    publish_platform_legal_documents
    host! "aurora.painel.catalysthr.com.br"
  end

  def invite(channels: %w[link], **person)
    Invitations::Create.call(organization: company, roles: %w[hr_analyst], channels: channels, invited_by: inviter,
      name: "Joana Prado", cpf: "11144477735", email: nil, mobile_phone: "11987654321", **person)
  end

  def accept(token, password: "Joana#2026", confirmation: password)
    patch "/invitation", params: { token: token, password: password, password_confirmation: confirmation }
  end

  it "takes a person without e-mail from the link to the password, then to the terms (CA-02-001)" do
    invitation = invite

    get "/invitation", params: { token: invitation.token }
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Olá, Joana. Boas-vindas!", "crie a sua senha")

    accept(invitation.token)
    expect(response).to redirect_to("/")
    expect(invitation.membership.reload).to be_active

    get "/"
    expect(response).to redirect_to("/first-access/terms")
  end

  it "refuses a password outside the rules and keeps the invitation open (RN-02-030)" do
    invitation = invite

    accept(invitation.token, password: "catalyst1")

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("precisa ter pelo menos uma letra maiúscula")
    expect(invitation.membership.reload).to be_invited
  end

  it "expires after 72 hours (CA-02-001)" do
    invitation = invite

    travel 72.hours + 1.minute do
      get "/invitation", params: { token: invitation.token }
      expect(response).to have_http_status(:not_found)
      expect(response.body).to include("Convite expirado")
    end
  end

  it "shows the old link of a resent invitation as expired (CA-02-002)" do
    first = invite
    Invitations::Resend.call(membership: first.membership, channels: %w[link], invited_by: inviter)

    get "/invitation", params: { token: first.token }

    expect(response.body).to include("Convite expirado")
  end

  it "works once" do
    invitation = invite
    accept(invitation.token)
    delete "/sign-out"

    get "/invitation", params: { token: invitation.token }
    expect(response.body).to include("Convite expirado")
  end

  it "only opens on the subdomain of the invitation's brand" do
    invitation = invite
    create(:brand, commercial_name: "Outra marca").subdomains.create!(slug: "outra")

    host! "outra.painel.catalysthr.com.br"
    get "/invitation", params: { token: invitation.token }

    expect(response.body).to include("Convite expirado")
  end

  describe "a person who already has a password (RN-02-013)" do
    let!(:existing) { create(:user, cpf: "11144477735", name: "Joana Prado", password: "Antiga#2026") }

    before { create(:membership, user: existing, organization: create(:company)) }

    it "confirms the current password instead of creating another" do
      invitation = invite

      get "/invitation", params: { token: invitation.token }
      expect(response.body).to include("confirme a senha que você já usa")

      accept(invitation.token, password: "Antiga#2026")
      expect(response).to redirect_to("/")
      expect(existing.reload.valid_password?("Antiga#2026")).to be(true)
    end

    it "counts wrong passwords toward the lockout (RN-02-031)" do
      invitation = invite

      5.times { accept(invitation.token, password: "Errada#2026") }

      expect(response).to have_http_status(:unprocessable_content)
      expect(existing.reload).to be_access_locked
      expect(invitation.membership.reload).to be_invited
    end
  end
end
