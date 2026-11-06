require "rails_helper"

# Spec 15, block 15c (D-654): the push in the engine: the channels, the quiet hours, the hold,
# the release, the fallback and the catalog. No real call to a push service.
RSpec.describe "Notifications by push" do
  include ActiveJob::TestHelper

  let(:company) { create(:company) }
  let(:brand) { create(:brand, owner: company, commercial_name: "Serra Azul RH") }
  let(:user) { create(:user, email: "maria@example.com") }
  let(:membership) { create(:membership, user: user, organization: company, roles: %w[employee]) }
  let(:zone) { ActiveSupport::TimeZone["America/Sao_Paulo"] }
  let(:sent_messages) { [] }
  let(:keys) { { p256dh: Base64.urlsafe_encode64("\x04" + ("a" * 64)), auth: Base64.urlsafe_encode64("b" * 16) } }

  before do
    brand.subdomains.create!(slug: "serraazul")
    Flipper.enable(FeatureFlags::PUSH_NOTIFICATIONS)
    allow(WebPush).to receive(:payload_send) { |**args| sent_messages << JSON.parse(args[:message]) }
  end

  def subscribe(name = "abc", to: user)
    PushSubscription.create!(user: to, brand: brand, endpoint: "https://fcm.googleapis.com/fcm/send/#{name}", **keys)
  end

  def acknowledgment(key = "doc-1")
    Notifications.notify!("documents.acknowledgment_pending", user: user, membership: membership, path: "/portal/documents",
      dedup_key: key, title: "Regulamento", due: "10/11/2026")
  end

  def requested(key)
    Notifications.notify!("documents.requested", user: user, membership: membership, path: "/portal/documents", dedup_key: key,
      document: "RG", due: "10/11/2026")
  end

  it "shows the bell and the e-mail at once and holds the push until 8h of the next business day (CA-15-001)" do
    subscribe
    travel_to zone.parse("2026-11-04 21:00")
    notification = perform_enqueued_jobs { acknowledgment }

    expect(notification.in_bell).to be(true)
    expect(notification.deliveries.find_by(channel: "email")).to have_attributes(status: "sent")
    expect(notification.deliveries.find_by(channel: "push")).to have_attributes(status: "held", held_until: zone.parse("2026-11-05 08:00"))
    expect(WebPush).not_to have_received(:payload_send)

    travel_to zone.parse("2026-11-05 07:55")
    perform_enqueued_jobs { Notifications::ReleaseHeldJob.perform_now }
    expect(WebPush).not_to have_received(:payload_send)

    travel_to zone.parse("2026-11-05 08:00")
    perform_enqueued_jobs { Notifications::ReleaseHeldJob.perform_now }
    expect(notification.deliveries.find_by(channel: "push").status).to eq("sent")
    expect(WebPush).to have_received(:payload_send).once
  ensure
    travel_back
  end

  it "sends the push at once within the hours, to every device of the person in the brand (RN-15-004)" do
    subscribe("a")
    subscribe("b")
    other_brand = create(:brand, owner: create(:company))
    PushSubscription.create!(user: user, brand: other_brand, endpoint: "https://fcm.googleapis.com/fcm/send/other", **keys)
    travel_to zone.parse("2026-11-04 10:00")
    notification = perform_enqueued_jobs { acknowledgment }

    expect(WebPush).to have_received(:payload_send).twice
    expect(notification.deliveries.find_by(channel: "push")).to have_attributes(status: "sent", attempts: 1)
    expect(sent_messages.first).to include("title" => notification.title, "path" => "/notifications/#{notification.id}", "icon" => "/icon.png")
  ensure
    travel_back
  end

  it "leaves security notices out of the quiet hours (RN-15-033)" do
    subscribe
    user.update_columns(email: nil)
    travel_to zone.parse("2026-11-04 23:00")
    notification = Notifications.notify!("security.passkey_added", user: user, membership: membership, path: "/security", nickname: "iPhone",
      brand_name: "Serra Azul RH")

    expect(notification.deliveries.sole).to have_attributes(channel: "push", status: "queued", held_until: nil)
  ensure
    travel_back
  end

  it "creates no push without a subscription, with the flag off or when the person turned it off (RN-15-023)" do
    travel_to zone.parse("2026-11-04 10:00")
    expect(acknowledgment("a").deliveries.pluck(:channel)).to eq(%w[email])

    subscribe
    Flipper.disable(FeatureFlags::PUSH_NOTIFICATIONS)
    expect(acknowledgment("b").deliveries.pluck(:channel)).to eq(%w[email])

    Flipper.enable(FeatureFlags::PUSH_NOTIFICATIONS)
    NotificationPreference.create!(membership: membership, notification_type: "documents.acknowledgment_pending", channels: %w[email])
    expect(acknowledgment("c").deliveries.pluck(:channel)).to eq(%w[email])
  ensure
    travel_back
  end

  it "keeps the push of a type to the roles the catalog gives it (spec 15, section 4.2)" do
    type = NotificationType.find("processes.task_overdue")

    expect(type.configurable_channels(%w[manager])).to include("push")
    expect(type.configurable_channels(%w[hr_admin])).not_to include("push")
    expect(type.configurable_channels).to include("push")
  end

  it "cancels at the release what the person already opened (RN-15-035, CA-15-004)" do
    subscribe
    travel_to zone.parse("2026-11-04 21:00")
    notification = acknowledgment

    travel_to zone.parse("2026-11-05 07:00")
    notification.read!
    travel_to zone.parse("2026-11-05 08:00")
    perform_enqueued_jobs { Notifications::ReleaseHeldJob.perform_now }

    expect(notification.deliveries.find_by(channel: "push").status).to eq("cancelled")
    expect(WebPush).not_to have_received(:payload_send)
  ensure
    travel_back
  end

  it "groups what is held of the same type into one message that opens the bell (RN-15-034)" do
    subscribe
    travel_to zone.parse("2026-11-04 21:00")
    first, second, third = %w[a b c].map { |key| requested(key) }
    other = acknowledgment

    travel_to zone.parse("2026-11-05 08:00")
    perform_enqueued_jobs { Notifications::ReleaseHeldJob.perform_now }

    expect(WebPush).to have_received(:payload_send).twice
    grouped = sent_messages.find { |message| message["title"].include?("3") }
    expect(grouped).to include("title" => "Você tem 3 documentos pedidos", "path" => "/portal/notifications")
    expect([ first, second, third ].map { |one| one.deliveries.reload.sole.status }).to all(eq("sent"))
    expect(other.deliveries.find_by(channel: "push").status).to eq("sent")
  ensure
    travel_back
  end

  it "sends nothing twice when the release runs again" do
    subscribe
    travel_to zone.parse("2026-11-04 21:00")
    acknowledgment

    travel_to zone.parse("2026-11-05 08:00")
    perform_enqueued_jobs do
      Notifications::ReleaseHeldJob.perform_now
      Notifications::ReleaseHeldJob.perform_now
    end

    expect(WebPush).to have_received(:payload_send).once
  ensure
    travel_back
  end

  it "tells nothing sensitive in the messages (RN-15-005, CA-15-013)" do
    NotificationType.all.select { |type| type.channels.include?("push") }.each do |type|
      expect(I18n.exists?("notification_types.#{type.code}.grouped")).to be(true), "#{type.code} has no grouped text"
      expect(I18n.t("notification_types.#{type.code}.grouped", count: 3)).not_to match(/R\$|salário|CID|apto|inapto/i)
    end
  end

  describe "the fallback (RN-15-081, D-654)" do
    before { travel_to zone.parse("2026-11-04 10:00") }
    after { travel_back }

    it "sends the mandatory notice by push when the e-mail bounces, even with the push turned off and off the catalog" do
      subscribe
      membership.update!(roles: %w[employee hr_admin])
      notification = perform_enqueued_jobs do
        Notifications.notify!("billing.invoice_issued", user: user, membership: membership, path: "/contract", dedup_key: "x",
          number: "1", name: "Serra Azul", total: "R$ 1.000,00", period_start: "01/10", period_end: "31/10", due: "10/11/2026")
      end
      email = notification.deliveries.sole
      expect(email.channel).to eq("email")
      email.update!(provider_message_id: "ses-1")

      perform_enqueued_jobs do
        Notifications::SesEvents.handle("eventType" => "Bounce", "mail" => { "messageId" => "ses-1" },
          "bounce" => { "bounceType" => "Permanent", "bouncedRecipients" => [] })
      end

      expect(notification.deliveries.reload.find_by(channel: "push")).to have_attributes(status: "sent", fallback_from_id: email.id)
      # Written for the e-mail, with the amount: only the type's name reaches the screen (RN-15-005).
      expect(sent_messages.sole).to include("title" => "Fatura disponível", "body" => nil)
    end

    it "makes one fallback per failed delivery" do
      subscribe
      NotificationPreference.create!(membership: membership, notification_type: "documents.acknowledgment_pending", channels: %w[email])
      notification = acknowledgment
      email = notification.deliveries.sole
      email.update_columns(status: "failed")

      2.times { Notifications::FallbackJob.perform_now(email) }

      expect(notification.deliveries.where(channel: "push").count).to eq(1)
    end

    it "waits for the quiet hours in the fallback's push" do
      subscribe
      travel_back
      travel_to zone.parse("2026-11-04 22:00")
      NotificationPreference.create!(membership: membership, notification_type: "documents.acknowledgment_pending", channels: %w[email])
      notification = acknowledgment
      email = notification.deliveries.sole
      email.update_columns(status: "failed")

      Notifications::FallbackJob.perform_now(email)

      expect(notification.deliveries.find_by(channel: "push")).to have_attributes(status: "held", held_until: zone.parse("2026-11-05 08:00"))
    end

    it "goes back to the e-mail when the push fails and the e-mail was not used" do
      subscribe
      NotificationPreference.create!(membership: membership, notification_type: "documents.acknowledgment_pending", channels: %w[push])
      allow(WebPush).to receive(:payload_send).and_raise(WebPush::ExpiredSubscription.new(double(body: "", inspect: "410"), "fcm.googleapis.com"))
      notification = perform_enqueued_jobs { acknowledgment }

      expect(notification.deliveries.reload.pluck(:channel, :status)).to contain_exactly([ "push", "failed" ], [ "email", "sent" ])
      expect(PushSubscription.count).to eq(0)
    end

    it "has no fallback for optional notices (RN-15-082)" do
      subscribe
      allow(WebPush).to receive(:payload_send).and_raise(WebPush::ExpiredSubscription.new(double(body: "", inspect: "410"), "fcm.googleapis.com"))
      notification = perform_enqueued_jobs { requested("a") }

      expect(notification.deliveries.reload.pluck(:channel, :status)).to eq([ [ "push", "failed" ] ])
      expect(ActionMailer::Base.deliveries).to be_empty
    end

    it "uses the push when the mandatory notice has no channel chosen that the person can get" do
      subscribe
      user.update_columns(email: nil, email_status: "valid")
      notification = acknowledgment

      expect(notification.deliveries.sole).to have_attributes(channel: "push", status: "queued")
    end
  end
end
