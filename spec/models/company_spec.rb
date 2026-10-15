require "rails_helper"

RSpec.describe Company do
  it "stores the CNPJ normalized and rejects an invalid one" do
    company = create(:company, cnpj: "12.abc.345/01de-35")
    expect(company.cnpj).to eq("12ABC34501DE35")

    invalid = build(:company, cnpj: "11.222.333/0001-82")
    expect(invalid).not_to be_valid
    expect(invalid.errors[:cnpj]).to include("não é um CNPJ válido")
  end

  it "does not repeat a CNPJ" do
    create(:company, cnpj: "11222333000181")
    expect(build(:company, cnpj: "11.222.333/0001-81")).not_to be_valid
  end

  describe "brand display mode (RN-01-034)" do
    it "defaults to alongside for a partner's company" do
      expect(create(:company, :with_partner)).to be_brand_alongside
    end

    it "is not allowed for a direct company" do
      company = build(:company, brand_display_mode: "replace")
      expect(company).not_to be_valid
    end
  end

  it "reaches its partner's brand, or its own when direct (D-154)" do
    partner_brand = create(:brand)
    company = create(:company, partner: partner_brand.owner)
    expect(company.subdomain_brand).to eq(partner_brand)

    direct = create(:company)
    direct_brand = create(:brand, owner: direct)
    expect(direct.subdomain_brand).to eq(direct_brand)
  end
end
