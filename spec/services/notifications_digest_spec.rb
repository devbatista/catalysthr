require "rails_helper"

# Spec 15, block 15d (RN-15-040 to RN-15-044, D-655): the daily digest by e-mail. No real
# call to SES.
RSpec.describe "Daily digest" do
  include ActiveJob::TestHelper

  let(:company) { create(:company) }
  let(:brand) { create(:brand, owner: company, commercial_name: "Serra Azul RH") }
  let(:user) { create(:user, name: "Juliana Ribeiro", email: "juliana@example.com") }
  let(:membership) { create(:membership, user: user, organization: company, roles: %w[hr_admin employee]) }
  let(:zone) { ActiveSupport::TimeZone["America/Sao_Paulo"] }
  let(:mails) { ActionMailer::Base.deliveries }

  before do
    brand.subdomains.create!(slug: "serraazul")
    Flipper.enable(FeatureFlags::NOTIFICATION_DIGEST)
  end

  after { travel_back }

  def review(key, on: membership, by: user)
    Notifications.notify!("documents.review_pending", user: by, membership: on, path: "/documents", dedup_key: key,
      document: "RG #{key}", person: "Ana Lima")
  end

  def run_digest(time)
    travel_to zone.parse(time)
    perform_enqueued_jobs { Notifications::DigestJob.perform_now }
  end

  # 2026-11-04 is a Wednesday.
  it "sends one e-mail with the unread items at 7h30 of the next day (CA-15-005)" do
    travel_to zone.parse("2026-11-04 09:00")
    notices = (1..12).map { |number| perform_enqueued_jobs { review(number) } }
    expect(mails).to be_empty
    notices.first.read!

    run_digest("2026-11-05 07:00")
    expect(mails).to be_empty

    run_digest("2026-11-05 07:30")
    mail = mails.sole
    expect(mail.subject).to eq("Resumo de Serra Azul RH: 11 avisos pendentes")
    expect(mail[:from].to_s).to include("Serra Azul RH")
    expect(mail.html_part.body.to_s).to include("Você tem 11 avisos ainda não lidos.", notices.last.title, "/notifications/#{notices.last.id}")
    expect(mail.html_part.body.to_s).not_to include(notices.first.title)

    digest = NotificationDigest.sole
    expect(digest.notification_ids).to match_array(notices.drop(1).map(&:id))
    expect(notices.first.deliveries.reload.sole.status).to eq("cancelled")
    expect(notices.last.deliveries.reload.sole).to have_attributes(status: "sent", digest_id: digest.id)
  end

  it "sends nothing with everything read, and nothing twice (RN-15-041)" do
    travel_to zone.parse("2026-11-04 09:00")
    read = review("a")
    read.read!

    run_digest("2026-11-05 07:30")
    expect(mails).to be_empty
    expect(NotificationDigest.count).to eq(0)

    review("b")
    run_digest("2026-11-06 07:30")
    run_digest("2026-11-06 08:00")
    expect(mails.size).to eq(1)
  end

  it "brings the weekend on Monday and sends nothing on Saturday (RN-15-041)" do
    travel_to zone.parse("2026-11-06 12:00")
    friday = review("friday")
    travel_to zone.parse("2026-11-07 12:00")
    saturday = review("saturday")
    expect(saturday.deliveries.sole.held_until).to eq(zone.parse("2026-11-09 07:30"))
    expect(friday.deliveries.sole.held_until).to eq(zone.parse("2026-11-09 07:30"))

    run_digest("2026-11-09 07:30")
    expect(NotificationDigest.sole.notification_ids).to contain_exactly(friday.id, saturday.id)
  end

  it "keeps each person's hour in the unit's time zone" do
    ActsAsTenant.with_tenant(company) { company.headquarters.update!(time_zone: "America/Manaus") }
    travel_to zone.parse("2026-11-04 09:00")
    notice = review("a")

    expect(notice.deliveries.sole.held_until).to eq(ActiveSupport::TimeZone["America/Manaus"].parse("2026-11-05 07:30"))
  end

  it "sends the urgent ones at once (RN-15-042, CA-15-006)" do
    travel_to zone.parse("2026-11-04 15:00")
    notice = perform_enqueued_jobs do
      Notifications.notify!("admission.aso_unfit", user: user, membership: membership, path: "/admissions", person: "Ana Lima")
    end

    expect(notice.deliveries.reload.sole.status).to eq("sent")
    expect(notice.in_bell).to be(true)
    expect(mails.size).to eq(1)
  end

  it "leaves security, the contract and the person's own notices one by one (D-655)" do
    travel_to zone.parse("2026-11-04 15:00")
    perform_enqueued_jobs do
      Notifications.notify!("security.mfa_reset", user: user, membership: membership, path: "/security", brand_name: "Serra Azul RH")
      Notifications.notify!("billing.invoice_issued", user: user, membership: membership, path: "/contract", dedup_key: "x", number: "1",
        name: "Serra Azul", total: "R$ 1,00", period_start: "01/10", period_end: "31/10", due: "10/11/2026")
      Notifications.notify!("documents.acknowledgment_pending", user: user, membership: membership, path: "/portal", title: "Regulamento",
        due: "10/11/2026")
    end

    expect(mails.size).to eq(3)
    expect(NotificationDelivery.held).to be_empty
  end

  it "takes the profile into account: a client's manager and a partner's administrator have no digest (RN-15-040)" do
    expect(NotificationType.find("processes.task_overdue").digest_for?(%w[client_manager])).to be(false)
    expect(NotificationType.find("processes.task_overdue").digest_for?(%w[manager])).to be(true)
    expect(NotificationType.find("contacts.email_invalid").digest_for?(%w[partner_admin])).to be(false)
    expect(NotificationType.find("contacts.email_invalid").digest_for?(%w[firm_admin])).to be(true)
    expect(NotificationType.find("documents.requested").digest_for?(%w[employee hr_admin])).to be(false)
  end

  it "makes one digest per membership, each with its own brand (D-655)" do
    other_company = create(:company)
    other_brand = create(:brand, owner: other_company, commercial_name: "Aurora RH")
    other_brand.subdomains.create!(slug: "aurora")
    other = create(:membership, user: user, organization: other_company, roles: %w[hr_admin])
    travel_to zone.parse("2026-11-04 09:00")
    review("a")
    review("b", on: other)

    run_digest("2026-11-05 07:30")

    expect(mails.map(&:subject)).to contain_exactly("Resumo de Serra Azul RH: 1 aviso pendente", "Resumo de Aurora RH: 1 aviso pendente")
    expect(NotificationDigest.pluck(:brand_id)).to contain_exactly(brand.id, other_brand.id)
  end

  it "sends one by one with the flag off" do
    Flipper.disable(FeatureFlags::NOTIFICATION_DIGEST)
    travel_to zone.parse("2026-11-04 09:00")
    notice = perform_enqueued_jobs { review("a") }

    expect(notice.deliveries.reload.sole.status).to eq("sent")
    expect(mails.size).to eq(1)
  end

  it "keeps out of the release of the quiet hours" do
    travel_to zone.parse("2026-11-04 09:00")
    notice = review("a")

    travel_to zone.parse("2026-11-05 08:00")
    perform_enqueued_jobs { Notifications::ReleaseHeldJob.perform_now }

    expect(notice.deliveries.reload.sole.status).to eq("held")
  end

  it "does not send to an e-mail that bounced in the meantime" do
    travel_to zone.parse("2026-11-04 09:00")
    notice = review("a")
    user.update_columns(email_status: "bounced")

    run_digest("2026-11-05 07:30")

    expect(mails).to be_empty
    expect(notice.deliveries.reload.sole).to have_attributes(status: "failed", failed_reason: "email_unavailable")
  end

  describe "the SES events and the fallback (RN-15-080, RN-15-081)" do
    let(:keys) { { p256dh: Base64.urlsafe_encode64("\x04" + ("a" * 64)), auth: Base64.urlsafe_encode64("b" * 16) } }

    def mandatory
      Notifications.notify!("employments.probation_ending", user: user, membership: membership, path: "/employees", dedup_key: "p",
        person: "Ana Lima", date: "10/11/2026")
    end

    def digest_with(notice)
      NotificationDigest.create!(recipient_membership: membership, brand: brand, notification_ids: [ notice.id ], provider_message_id: "ses-9",
        sent_at: Time.current).tap { |digest| notice.deliveries.sole.update!(digest: digest, status: "sent") }
    end

    before { travel_to zone.parse("2026-11-04 10:00") }

    it "marks every delivery of the digest delivered" do
      notice = review("a")
      digest_with(notice)

      Notifications::SesEvents.handle("eventType" => "Delivery", "mail" => { "messageId" => "ses-9" })

      expect(notice.deliveries.sole.reload.status).to eq("delivered")
    end

    it "sends a mandatory notice of a bounced digest through the next channel, at once" do
      Flipper.enable(FeatureFlags::PUSH_NOTIFICATIONS)
      allow(WebPush).to receive(:payload_send)
      PushSubscription.create!(user: user, brand: brand, endpoint: "https://fcm.googleapis.com/fcm/send/a", **keys)
      NotificationPreference.create!(membership: membership, notification_type: "employments.probation_ending", channels: %w[email])
      membership.update!(roles: %w[hr_admin manager])
      notice = mandatory
      digest_with(notice)

      perform_enqueued_jobs do
        Notifications::SesEvents.handle("eventType" => "Bounce", "mail" => { "messageId" => "ses-9" },
          "bounce" => { "bounceType" => "Permanent", "bouncedRecipients" => [] })
      end

      expect(notice.deliveries.reload.pluck(:channel, :status)).to contain_exactly([ "email", "failed" ], [ "push", "sent" ])
    end
  end

  it "fails every delivery of a digest SES refuses" do
    travel_to zone.parse("2026-11-04 09:00")
    notice = review("a")
    allow(NotificationMailer).to receive(:digest).and_wrap_original do |original, *args|
      original.call(*args).tap { |mail| allow(mail).to receive(:deliver_now).and_raise(Aws::SESV2::Errors::MessageRejected.new(nil, "no")) }
    end

    run_digest("2026-11-05 07:30")

    expect(notice.deliveries.reload.sole).to have_attributes(status: "failed", failed_reason: "MessageRejected")
    expect(NotificationDigest.sole.sent_at).to be_nil
  end

  it "deletes the digests after 1 year (RN-15-090)" do
    NotificationDigest.create!(recipient_membership: membership, created_at: 13.months.ago)
    recent = NotificationDigest.create!(recipient_membership: membership)

    Notifications::PurgeJob.perform_now

    expect(NotificationDigest.pluck(:id)).to eq([ recent.id ])
  end
end
