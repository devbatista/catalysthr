require "rails_helper"

RSpec.describe BrandSubdomain do
  describe "slug format (RN-01-020)" do
    %w[abc aurora-gp serra2 a1b].each do |slug|
      it "accepts #{slug}" do
        expect(build(:brand_subdomain, slug: slug)).to be_valid
      end
    end

    [ "ab", "a" * 41, "-aurora", "aurora-", "aurora_gp", "aurorá", "auro ra" ].each do |slug|
      it "rejects #{slug.inspect}" do
        subdomain = build(:brand_subdomain, slug: slug)
        expect(subdomain).not_to be_valid
        expect(subdomain.errors[:slug]).to be_present
      end
    end

    it "downcases the slug" do
      expect(create(:brand_subdomain, slug: "Aurora").slug).to eq("aurora")
    end
  end

  describe "reserved slugs (RN-01-021)" do
    it "refuses a built-in reserved slug (CA-01-013)" do
      subdomain = build(:brand_subdomain, slug: "admin")

      expect(subdomain).not_to be_valid
      expect(subdomain.errors[:slug]).to include("é um nome reservado")
    end

    it "refuses a slug the superadmin reserved" do
      ReservedSlug.create!(slug: "folha")

      expect(build(:brand_subdomain, slug: "folha")).not_to be_valid
    end
  end

  describe "uniqueness" do
    it "keeps a slug taken while it is active or redirecting" do
      create(:brand_subdomain, slug: "aurora", status: "redirecting", redirect_until: 10.days.from_now)

      expect(build(:brand_subdomain, slug: "aurora")).not_to be_valid
    end

    it "frees a released slug for another brand" do
      create(:brand_subdomain, slug: "aurora", status: "released")

      expect(build(:brand_subdomain, slug: "aurora")).to be_valid
    end
  end

  it "belongs only to a partner's or a direct company's brand (D-154)" do
    company = create(:company, :with_partner)
    own_brand = create(:brand, owner: company)

    subdomain = build(:brand_subdomain, brand: own_brand)
    expect(subdomain).not_to be_valid
    expect(subdomain.errors[:brand]).to be_present

    direct_brand = create(:brand, owner: create(:company))
    expect(build(:brand_subdomain, brand: direct_brand)).to be_valid
  end
end
