require "rails_helper"

RSpec.describe Brand do
  describe "primary color contrast (RN-01-031)" do
    it "refuses a primary color below 4.5:1 against white and explains why (CA-01-010)" do
      brand = build(:brand, primary_color: "#FFD966")

      expect(brand).not_to be_valid
      expect(brand.errors[:primary_color].first).to match(/contraste mínimo de 4,5:1.*contraste atual: 1,\d:1/)
    end

    it "accepts a primary color with enough contrast" do
      expect(build(:brand, primary_color: "#085087")).to be_valid
    end

    it "rejects a color that is not #RRGGBB" do
      expect(build(:brand, secondary_color: "blue")).not_to be_valid
    end
  end

  it "falls back to the CatalystHR colors for empty fields (RN-01-032)" do
    brand = build(:brand, primary_color: "#6b2fa3")

    expect(brand.colors).to eq(primary: "#6B2FA3", secondary: "#0A2A4A", accent: "#1E9C86")
  end

  it "uses the short name for the app, or the commercial name" do
    expect(build(:brand, short_name: "Aurora").app_name).to eq("Aurora")
    expect(build(:brand, short_name: nil).app_name).to eq("Aurora RH")
  end

  it "accepts PNG images and refuses SVG, which can carry scripts" do
    brand = create(:brand)
    brand.logo_light.attach(io: StringIO.new("<svg/>"), filename: "logo.svg", content_type: "image/svg+xml")

    expect(brand).not_to be_valid
    expect(brand.errors[:logo_light]).to include("precisa ser uma imagem PNG, JPEG ou WebP")
  end
end
