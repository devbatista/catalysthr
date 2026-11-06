require "rails_helper"

# Spec 15, block 15c (RN-15-080, RN-15-084, P-15-33): Web Push with the real cipher and the
# service answered by WebMock. No real call.
RSpec.describe Notifications::DeliverPushJob do
  include ActiveJob::TestHelper

  let(:company) { create(:company) }
  let(:brand) { create(:brand, owner: company) }
  let(:user) { create(:user) }
  let(:membership) { create(:membership, user: user, organization: company, roles: %w[employee]) }
  let(:device_key) { OpenSSL::PKey::EC.generate("prime256v1") }
  let(:p256dh) { Base64.urlsafe_encode64(device_key.public_key.to_bn.to_s(2)) }
  let(:auth) { Base64.urlsafe_encode64(SecureRandom.random_bytes(16)) }
  let(:notification) do
    Notification.create!(notification_type: "documents.requested", recipient_user: user, recipient_membership: membership, company: company,
      brand: brand, area: "panel", path: "/portal/documents", title: "Documento pedido", body: "Envie o RG.")
  end
  let(:delivery) { notification.deliveries.create!(channel: "push") }

  def subscription(name)
    PushSubscription.create!(user: user, brand: brand, endpoint: "https://fcm.googleapis.com/fcm/send/#{name}", p256dh: p256dh, auth: auth)
  end

  it "ciphers the message and marks the delivery sent, with the urgency of the notice" do
    device = subscription("a")
    request = stub_request(:post, device.endpoint).with(headers: { "Content-Encoding" => "aes128gcm", "Urgency" => "normal" }).to_return(status: 201)

    described_class.perform_now(delivery)

    expect(request).to have_been_requested
    expect(delivery.reload).to have_attributes(status: "sent", attempts: 1, failed_reason: nil)
    expect(device.reload.last_success_at).to be_present
  end

  it "deletes a subscription the service says is gone (RN-15-080)" do
    gone = subscription("gone")
    missing = subscription("missing")
    alive = subscription("alive")
    stub_request(:post, gone.endpoint).to_return(status: 410)
    stub_request(:post, missing.endpoint).to_return(status: 404)
    stub_request(:post, alive.endpoint).to_return(status: 201)

    described_class.perform_now(delivery)

    expect(PushSubscription.pluck(:id)).to eq([ alive.id ])
    expect(delivery.reload.status).to eq("sent")
  end

  it "tries again 1, 5 and 15 minutes apart, only the devices that failed, before failing (RN-15-084)" do
    fine = subscription("fine")
    down = subscription("down")
    fine_request = stub_request(:post, fine.endpoint).to_return(status: 201)
    down_request = stub_request(:post, down.endpoint).to_return(status: 503)

    expect { described_class.perform_now(delivery) }.to have_enqueued_job(described_class).with(delivery, [ down.id ], 1).at(a_value_within(5.seconds).of(1.minute.from_now))
    expect(delivery.reload.status).to eq("sending")

    expect { described_class.perform_now(delivery, [ down.id ], 1) }.to have_enqueued_job.at(a_value_within(5.seconds).of(5.minutes.from_now))
    expect { described_class.perform_now(delivery, [ down.id ], 2) }.to have_enqueued_job.at(a_value_within(5.seconds).of(15.minutes.from_now))
    described_class.perform_now(delivery, [ down.id ], 3)

    expect(fine_request).to have_been_requested.once
    expect(down_request).to have_been_requested.times(4)
    expect(delivery.reload.status).to eq("sent")
  end

  it "fails after the attempts when no device took it" do
    down = subscription("down")
    stub_request(:post, down.endpoint).to_return(status: 429)

    described_class.perform_now(delivery, [ down.id ], 3)

    expect(delivery.reload).to have_attributes(status: "failed", failed_reason: "temporary")
  end

  it "fails with no subscription left and reports wrong keys to the team" do
    described_class.perform_now(delivery)
    expect(delivery.reload).to have_attributes(status: "failed", failed_reason: "no_subscription")

    other = notification.deliveries.create!(channel: "push")
    device = subscription("forbidden")
    stub_request(:post, device.endpoint).to_return(status: 403)
    expect(Rails.error).to receive(:report).with(an_instance_of(WebPush::Unauthorized), hash_including(:context))

    described_class.perform_now(other)

    expect(other.reload).to have_attributes(status: "failed", failed_reason: "unauthorized")
    expect(device.reload).to be_persisted
  end

  it "leaves a delivery already finished alone" do
    delivery.update!(status: "sent")

    described_class.perform_now(delivery)

    expect(delivery.reload.attempts).to eq(0)
  end
end
