require "rails_helper"

RSpec.describe Company do
  describe "the employer's document (RN-04-001, P-04-04)" do
    it "keeps the CNPJ root normalized, alphanumeric included, and refuses a full CNPJ" do
      company = create(:company, document: "12.abc.345")
      expect(company.document).to eq("12ABC345")

      invalid = build(:company, document: "11.222.333/0001-81")
      expect(invalid).not_to be_valid
      expect(invalid.errors[:document]).to include("precisa ser a raiz do CNPJ, com 8 caracteres")
    end

    it "takes a valid CPF for a person employer (D-200)" do
      expect(create(:company, employer_type: "person", document: "123.456.789-09").formatted_document).to eq("123.456.789-09")
      expect(build(:company, employer_type: "person", document: "12345678900")).not_to be_valid
    end

    it "is unique on the platform, and searchable though encrypted" do
      create(:company, document: "11222333")
      expect(build(:company, document: "11.222.333")).not_to be_valid
      expect(described_class.matching("11.222.333/0001-81").count).to eq(1)
    end
  end

  it "is born with its headquarters unit (RN-04-010, P-04-05)" do
    company = create(:company)

    expect(company.headquarters).to have_attributes(name: "Matriz", headquarters: true, status: "active",
      time_zone: "America/Sao_Paulo")
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

  describe ".operable_by (RN-01-005, RN-01-011)" do
    let(:brand) { create(:brand) }
    let(:partner) { brand.owner }
    let(:user) { create(:user) }

    it "lists the companies with a membership and the ones assigned to the consultant (D-052, D-192)" do
      own = create(:company, partner: partner)
      assigned = create(:company, partner: partner)
      create(:company, partner: partner)
      create(:membership, user: user, organization: own, roles: %w[manager])
      consultant = create(:membership, user: user, organization: partner, roles: %w[consultant])
      consultant.partner_membership_companies.create!(company: assigned)

      expect(described_class.operable_by(user, brand: brand)).to contain_exactly(own, assigned)
    end

    it "leaves out the partner's administrator without the consultant role (P-03-01)" do
      create(:company, partner: partner)
      create(:membership, user: user, organization: partner, roles: %w[partner_admin])

      expect(described_class.operable_by(user, brand: brand)).to be_empty
    end

    it "drops an assigned company moved to another partner (RN-01-052)" do
      assigned = create(:company, partner: partner)
      consultant = create(:membership, user: user, organization: partner, roles: %w[consultant])
      consultant.partner_membership_companies.create!(company: assigned)

      assigned.update!(partner: create(:partner))

      expect(described_class.operable_by(user, brand: brand)).to be_empty
    end
  end
end
