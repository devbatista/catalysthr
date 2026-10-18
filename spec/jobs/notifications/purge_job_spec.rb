require "rails_helper"

# Spec 15, RN-15-090 (D-608): out of the bell after 90 days, deleted with the deliveries
# after 1 year.
RSpec.describe Notifications::PurgeJob do
  let(:user) { create(:user, email: "maria@example.com") }

  def notice_from(time)
    travel_to(time) { Notifications.notify!("security.mfa_reset", user: user, path: "/security", brand_name: "CatalystHR") }
  end

  it "archives the old notices and deletes the ones older than a year with their deliveries" do
    recent = notice_from(10.days.ago)
    old = notice_from(100.days.ago)
    ancient = notice_from(13.months.ago)

    described_class.perform_now

    expect(recent.reload.archived_at).to be_nil
    expect(old.reload.archived_at).to be_present
    expect(Notification.exists?(ancient.id)).to be(false)
    expect(NotificationDelivery.where(notification_id: ancient.id)).to be_empty
    expect(Notification.in_bell).to eq([ recent ])
  end
end
