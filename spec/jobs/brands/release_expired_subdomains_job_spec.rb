require "rails_helper"

RSpec.describe Brands::ReleaseExpiredSubdomainsJob do
  it "releases the slugs whose redirect is over and leaves the others" do
    brand = create(:brand)
    brand.subdomains.create!(slug: "auroranova")
    expired = brand.subdomains.create!(slug: "aurora", status: "redirecting", redirect_until: 1.minute.ago)
    current = brand.subdomains.create!(slug: "auroragp", status: "redirecting", redirect_until: 1.day.from_now)

    described_class.perform_now
    described_class.perform_now

    expect(expired.reload).to be_released
    expect(current.reload).to be_redirecting
  end
end
