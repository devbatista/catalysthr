require "rails_helper"

RSpec.describe "Daily purge of devices and sessions" do
  let(:user) { create(:user) }

  it "deletes expired or forgotten devices and keeps the active ones (RN-02-043)" do
    active = TrustedDevice.find_by!(token_digest: SecureToken.digest(TrustedDevice.remember!(user: user, user_agent: "A")))
    TrustedDevice.remember!(user: user, user_agent: "B")
    forgotten = user.trusted_devices.last
    forgotten.revoke!
    expired = TrustedDevice.find_by!(token_digest: SecureToken.digest(TrustedDevice.remember!(user: user, user_agent: "C")))
    expired.update_columns(expires_at: 1.minute.ago)

    TrustedDevices::PurgeExpiredJob.perform_now

    expect(TrustedDevice.all).to contain_exactly(active)
  end

  it "deletes sessions closed for more than 30 days (D-576)" do
    recent = UserSession.find_active(UserSession.start!(user: user, area: "admin", brand: nil, ip: "1.1.1.1", user_agent: "A"))
    old = UserSession.find_active(UserSession.start!(user: user, area: "admin", brand: nil, ip: "1.1.1.1", user_agent: "B"))
    old.update_columns(expires_at: 31.days.ago)
    recent.revoke!("sign_out")

    UserSessions::PurgeExpiredJob.perform_now
    UserSessions::PurgeExpiredJob.perform_now

    expect(UserSession.all).to contain_exactly(recent)
  end
end
