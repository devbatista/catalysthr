require "rails_helper"

# Spec 15, block 15a (D-607, D-608): the notices, the bell and the e-mail on behalf of the
# brand (RN-15-001, RN-15-002, RN-15-005 to RN-15-007, RN-15-023, RN-15-085).
RSpec.describe Notifications do
  include ActiveJob::TestHelper

  let(:partner) { create(:partner) }
  let(:brand) { create(:brand, owner: partner, commercial_name: "Aurora RH", primary_color: "#123456") }
  let(:company) { create(:company, partner: partner) }
  let(:user) { create(:user, name: "Maria Souza", email: "maria@example.com") }
  let(:membership) { create(:membership, user: user, organization: company, roles: %w[hr_admin]) }

  before { brand.subdomains.create!(slug: "aurora") }

  def mfa_reset(**options)
    described_class.notify!("security.mfa_reset", user: user, membership: membership, path: "/security", brand_name: "Aurora RH",
      **options)
  end

  it "puts the notice in the bell and sends it by e-mail on behalf of the brand, with a link that opens it" do
    notification = perform_enqueued_jobs { mfa_reset }

    expect(notification).to have_attributes(company: company, brand: brand, area: "panel", in_bell: true, mandatory: true,
      title: "Verificação em duas etapas redefinida em Aurora RH")
    expect(notification.deliveries.reload.sole).to have_attributes(channel: "email", status: "sent", destination_masked: "ma***@example.com")
    mail = ActionMailer::Base.deliveries.sole
    expect(mail.to).to eq([ "maria@example.com" ])
    expect(mail[:from].to_s).to eq("Aurora RH <no-reply@catalysthr.com.br>")
    expect(mail.subject).to eq(notification.title)
    expect(mail.html_part.body.to_s).to include("http://aurora.painel.catalysthr.com.br/notifications/#{notification.id}", "#123456",
      "O aviso também fica no sino")
    expect(mail.text_part.body.to_s).to include("Olá, Maria.", "ative de novo o app autenticador")
  end

  it "keeps a type without the bell out of it (D-608)" do
    notification = described_class.notify!("security.contact_changed", user: user, membership: membership, path: "/security",
      brand_name: "Aurora RH")

    expect(notification.in_bell).to be(false)
    expect(Notification.visible_to(user, area: :panel, brand: brand).in_bell).to be_empty
  end

  it "uses the bell alone when the person has no e-mail (RN-15-023)" do
    user.update!(email: nil, mobile_phone: "54999991234")

    expect(mfa_reset.deliveries).to be_empty
    expect(described_class.notify!("security.contact_changed", user: user, path: "/security", brand_name: "X")).to be_nil
  end

  it "makes one notice for the same type, person and origin in 12 hours (RN-15-085)" do
    first = mfa_reset(dedup_key: "reset/1")

    expect(mfa_reset(dedup_key: "reset/1")).to be_nil
    expect(mfa_reset(dedup_key: "reset/2")).to be_present
    travel 13.hours do
      expect(mfa_reset(dedup_key: "reset/1")).not_to eq(first)
    end
  end

  it "creates nothing during an impersonate (RN-15-007)" do
    Simulation.run { mfa_reset }

    expect(Notification.count).to eq(0)
    expect(enqueued_jobs).to be_empty
  end

  it "keeps the link inside the platform" do
    notification = Notification.new(notification_type: "security.mfa_reset", recipient_user: user, title: "x", path: "//evil.example")

    expect(notification).not_to be_valid
    expect(notification.errors[:path]).to be_present
  end

  describe "the bell of each area and brand (RN-01-013)" do
    let(:other_brand) { create(:brand, owner: create(:partner), commercial_name: "Outra RH") }
    let(:other_membership) do
      create(:membership, user: user, organization: create(:company, partner: other_brand.owner), roles: %w[hr_admin])
    end

    before { other_brand.subdomains.create!(slug: "outra") }

    it "shows each brand's notices on its own subdomain, the account's everywhere and the admin's in the admin" do
      mine = mfa_reset
      elsewhere = described_class.notify!("security.mfa_reset", user: user, membership: other_membership, path: "/security", brand_name: "Outra")
      account = described_class.notify!("security.account_locked", user: user, path: "/security")
      admin = described_class.notify!("brand.email_domain_status", user: user, brand: brand, area: "admin", path: "/brands/1/edit",
        variant: "verified", domain: "aurora.com.br", brand_name: "Aurora RH")

      expect(Notification.visible_to(user, area: :panel, brand: brand)).to contain_exactly(mine, account)
      expect(Notification.visible_to(user, area: :panel, brand: other_brand)).to contain_exactly(elsewhere, account)
      expect(Notification.visible_to(user, area: :admin)).to contain_exactly(account, admin)
    end
  end
end
