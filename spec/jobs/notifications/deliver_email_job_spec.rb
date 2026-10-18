require "rails_helper"

# Spec 15, RN-15-084 (P-15-27): three new attempts on a temporary failure of SES, 1, 5
# and 15 minutes apart; a refusal fails at once. No real call to SES.
RSpec.describe Notifications::DeliverEmailJob do
  include ActiveJob::TestHelper

  let(:user) { create(:user, email: "maria@example.com") }
  let(:notification) { Notifications.notify!("security.contact_changed", user: user, path: "/security", brand_name: "CatalystHR") }
  let(:delivery) { notification.deliveries.sole }

  def failing_with(error)
    allow(NotificationMailer).to receive(:notice).and_wrap_original do |original, *args|
      original.call(*args).tap { |mail| allow(mail).to receive(:deliver_now).and_raise(error) }
    end
  end

  it "sends once and keeps SES's message id" do
    allow(NotificationMailer).to receive(:notice).and_wrap_original do |original, *args|
      original.call(*args).tap { |mail| mail.message.header[:ses_message_id] = "ses-123" }
    end

    2.times { described_class.perform_now(delivery) }

    expect(delivery.reload).to have_attributes(status: "sent", attempts: 1, provider_message_id: "ses-123")
    expect(ActionMailer::Base.deliveries.size).to eq(1)
  end

  it "tries again 3 times after a temporary failure, then counts it as failed" do
    failing_with(Aws::SESV2::Errors::TooManyRequestsException.new(nil, "slow down"))

    perform_enqueued_jobs { described_class.perform_later(delivery) }

    expect(delivery.reload).to have_attributes(status: "failed", attempts: 4, failed_reason: "TooManyRequestsException")
  end

  it "fails at once when SES refuses the message" do
    failing_with(Aws::SESV2::Errors::MessageRejected.new(nil, "rejected"))

    perform_enqueued_jobs { described_class.perform_later(delivery) }

    expect(delivery.reload).to have_attributes(status: "failed", attempts: 1, failed_reason: "MessageRejected")
  end
end
