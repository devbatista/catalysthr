require "rails_helper"

# Spec 02, RN-02-070 to RN-02-073; D-586, D-589.
RSpec.describe AccountingFirm do
  let(:partner) { create(:partner) }
  let!(:brand) { create(:brand, owner: partner) }
  let(:company) { create(:company, partner: partner) }
  let(:firm) { create(:accounting_firm) }

  it "stores the CNPJ normalized and does not repeat it" do
    firm = create(:accounting_firm, cnpj: "11.222.333/0001-81")

    expect(firm.cnpj).to eq("11222333000181")
    expect(build(:accounting_firm, cnpj: "11222333000181")).not_to be_valid
  end

  it "keeps one pending or active link per company (D-589)" do
    create(:accounting_firm_company, company: company, status: "pending")

    expect(build(:accounting_firm_company, company: company, status: "active")).not_to be_valid
    expect(build(:accounting_firm_company, company: company, status: "ended")).to be_valid
  end

  describe "the team at a brand (D-586)" do
    let!(:accountant) { create(:membership, organization: firm, roles: %w[accountant]) }

    it "counts at a brand while the firm has a pending or active link there" do
      expect(Membership.for_brand(brand)).not_to include(accountant)

      link = create(:accounting_firm_company, accounting_firm: firm, company: company, status: "pending")
      expect(Membership.for_brand(brand)).to include(accountant)
      expect(Company.operable_by(accountant.user, brand: brand)).to be_empty

      link.update!(status: "active")
      expect(Company.operable_by(accountant.user, brand: brand)).to contain_exactly(company)

      link.update!(status: "ended")
      expect(Membership.for_brand(brand)).not_to include(accountant)
    end

    it "opens the brands of the companies the firm serves" do
      direct = create(:company)
      direct_brand = create(:brand, owner: direct)
      create(:accounting_firm_company, accounting_firm: firm, company: company)
      create(:accounting_firm_company, accounting_firm: firm, company: direct)

      expect(accountant.access_brands).to contain_exactly(brand, direct_brand)
    end
  end
end
