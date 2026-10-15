require "rails_helper"

RSpec.describe Brands::ChangeSlug do
  let(:brand) { create(:brand) }

  before { brand.subdomains.create!(slug: "aurora") }

  it "activates the new slug and keeps the old one redirecting for 90 days (RN-01-022)" do
    freeze_time do
      new_subdomain = described_class.call(brand: brand, slug: "AuroraGP")

      old = brand.subdomains.find_by(slug: "aurora")
      expect(new_subdomain).to have_attributes(slug: "auroragp", status: "active")
      expect(old).to have_attributes(status: "redirecting", redirect_until: 90.days.from_now)
    end
  end

  it "reactivates a slug of the same brand that is still redirecting" do
    described_class.call(brand: brand, slug: "auroragp")
    described_class.call(brand: brand, slug: "aurora")

    expect(brand.subdomains.find_by(slug: "aurora")).to be_active
    expect(brand.subdomains.find_by(slug: "auroragp")).to be_redirecting
    expect(brand.subdomains.count).to eq(2)
  end

  it "keeps everything as it was when the new slug is invalid" do
    expect { described_class.call(brand: brand, slug: "admin") }.to raise_error(ActiveRecord::RecordInvalid)

    expect(brand.subdomains.find_by(slug: "aurora")).to be_active
    expect(brand.subdomains.count).to eq(1)
  end

  it "points older redirects to the newest slug" do
    described_class.call(brand: brand, slug: "auroragp")
    described_class.call(brand: brand, slug: "auroranova")

    expect(Brands::HostLookup.call("aurora").target_slug).to eq("auroranova")
  end
end
