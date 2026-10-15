require "rails_helper"

# Spec 02, RN-02-010 to RN-02-013.
RSpec.describe Invitations do
  include ActiveJob::TestHelper

  let(:partner) { create(:partner) }
  let(:brand) { create(:brand, owner: partner, commercial_name: "Aurora RH", support_email: "suporte@aurora.example") }
  let(:company) { create(:company, partner: partner) }
  let(:inviter) { create(:user) }

  before { brand.subdomains.create!(slug: "aurora") }

  def invite(**overrides)
    Invitations::Create.call(organization: company, roles: %w[hr_analyst], channels: %w[email link], invited_by: inviter,
      name: "Joana Prado", cpf: "11144477735", email: "joana@example.com", **overrides)
  end

  describe Invitations::Create do
    it "creates the person without a password and the membership invited, valid for 72 hours (RN-02-010, RN-02-012)" do
      freeze_time do
        invitation = invite

        membership = invitation.membership
        expect(membership).to be_invited
        expect(membership.roles).to eq(%w[hr_analyst])
        expect(membership.invited_by).to eq(inviter)
        expect(membership.invitation_expires_at).to eq(72.hours.from_now)
        expect(membership.invitation_token_digest).to eq(Membership.token_digest(invitation.token))
        expect(membership.user).to have_attributes(name: "Joana Prado", email: "joana@example.com", password_set?: false)
      end
    end

    it "gives a link to the subdomain of the company's partner (RN-02-011)" do
      invitation = invite

      expect(invitation.link).to eq("http://aurora.painel.catalysthr.com.br/invitation?token=#{invitation.token}")
    end

    it "sends the e-mail from the brand, with the link, after the transaction (CA-01-008)" do
      invitation = perform_enqueued_jobs { invite }

      mail = ActionMailer::Base.deliveries.last
      expect(mail.to).to eq([ "joana@example.com" ])
      expect(mail.subject).to eq("Convite para acessar Aurora RH")
      expect(mail[:from].to_s).to eq("Aurora RH <nao-responda@catalysthr.com.br>")
      expect(mail.reply_to).to eq([ "suporte@aurora.example" ])
      expect(mail.text_part.body.to_s).to include(invitation.link)
    end

    it "sends nothing by e-mail when only the link is asked for (CA-02-001)" do
      invitation = perform_enqueued_jobs { invite(channels: %w[link], email: nil, mobile_phone: "11987654321") }

      expect(ActionMailer::Base.deliveries).to be_empty
      expect(invitation.membership.invitation_channels).to eq(%w[link])
    end

    it "reuses the person of a CPF already on the platform, without changing the data (RN-02-013)" do
      existing = create(:user, cpf: "11144477735", name: "Joana Prado Lima", email: "joana.lima@example.com")
      create(:membership, user: existing, organization: create(:company))

      membership = invite.membership

      expect(membership.user).to eq(existing)
      expect(existing.reload).to have_attributes(name: "Joana Prado Lima", email: "joana.lima@example.com")
      expect(existing.memberships.count).to eq(2)
    end

    it "refuses a person who already has access to the organization" do
      user = create(:user, cpf: "11144477735")
      create(:membership, user: user, organization: company)

      expect { invite }.to raise_error(ActiveRecord::RecordInvalid, /já tem acesso a esta organização/)
    end

    it "refuses WhatsApp until Twilio, and the e-mail channel for a person without e-mail" do
      expect { invite(channels: %w[whatsapp]) }.to raise_error(ActiveRecord::RecordInvalid, /ainda não está disponível/)
      expect { invite(channels: %w[email], email: nil, mobile_phone: "11987654321") }
        .to raise_error(ActiveRecord::RecordInvalid, /não tem e-mail cadastrado/)
      expect(User.count).to eq(1)
    end

    it "uses the company's name as the sender in replace mode (P-01-18)" do
      company.update!(brand_display_mode: "replace")
      create(:brand, owner: company, commercial_name: "Padaria Pão Quente")

      perform_enqueued_jobs { invite }

      from = ActionMailer::Base.deliveries.last[:from]
      expect(from.display_names).to eq([ "Padaria Pão Quente" ])
      expect(from.addresses).to eq([ "nao-responda@catalysthr.com.br" ])
    end
  end

  describe Invitations::Resend do
    it "replaces the token, so the previous link stops working (P-02-07)" do
      first = invite
      second = Invitations::Resend.call(membership: first.membership, channels: %w[link], invited_by: inviter)

      expect(Membership.find_by_invitation_token(first.token)).to be_nil
      expect(Membership.find_by_invitation_token(second.token)).to eq(first.membership)
    end

    it "skips the e-mail of a replaced token, even if the job runs late" do
      first = invite
      Invitations::Resend.call(membership: first.membership, channels: %w[link], invited_by: inviter)

      perform_enqueued_jobs

      expect(ActionMailer::Base.deliveries).to be_empty
    end

    it "refuses a membership no longer invited" do
      membership = invite.membership
      membership.accept_invitation!

      expect { Invitations::Resend.call(membership: membership, channels: %w[link], invited_by: inviter) }
        .to raise_error(ActiveRecord::RecordInvalid, /já foi aceito ou cancelado/)
    end
  end
end
