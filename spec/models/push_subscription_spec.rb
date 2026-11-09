require "rails_helper"

# Spec 15, block 15c (D-654): the address comes from the browser and the server posts to it,
# so only the browsers' push services get in (no SSRF).
RSpec.describe PushSubscription do
  let(:brand) { create(:brand, owner: create(:company)) }
  let(:keys) { { p256dh: Base64.urlsafe_encode64("\x04" + ("a" * 64)), auth: Base64.urlsafe_encode64("b" * 16) } }

  def subscription(endpoint, **attributes)
    described_class.new(user: create(:user), brand: brand, endpoint: endpoint, **keys, **attributes)
  end

  %w[
    https://fcm.googleapis.com/fcm/send/abc
    https://updates.push.services.mozilla.com/wpush/v2/abc
    https://web.push.apple.com/abc
    https://wns2-par02p.notify.windows.com/w/?token=abc
  ].each do |endpoint|
    it "accepts #{endpoint}" do
      expect(subscription(endpoint)).to be_valid
    end
  end

  %w[
    http://fcm.googleapis.com/fcm/send/abc
    https://169.254.169.254/latest/meta-data
    https://localhost/abc
    https://fcm.googleapis.com.evil.example/abc
    https://evil.example/fcm.googleapis.com
    https://fcm.googleapis.com:8443/abc
    https://user@fcm.googleapis.com/abc
    not-a-url
  ].each do |endpoint|
    it "refuses #{endpoint}" do
      expect(subscription(endpoint)).not_to be_valid
    end
  end

  it "refuses keys that are not the browser's" do
    expect(subscription("https://fcm.googleapis.com/fcm/send/abc", p256dh: "short")).not_to be_valid
    expect(subscription("https://fcm.googleapis.com/fcm/send/abc", auth: "%%%")).not_to be_valid
  end
end
