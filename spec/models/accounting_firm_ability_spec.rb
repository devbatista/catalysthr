require "rails_helper"

# Spec 02, RN-02-044 and RN-02-071; spec 03, section 4.2; D-582, D-584, D-586, D-590.
RSpec.describe AccountingFirmAbility do
  let(:partner) { create(:partner) }
  let(:brand) { create(:brand, owner: partner) }
  let(:company) { create(:company, partner: partner) }
  let(:firm) { create(:accounting_firm) }
  let(:admin) { create(:membership, organization: firm, roles: %w[firm_admin]).user }
  let(:ability) { described_class.new(admin, brand) }

  before { create(:accounting_firm_company, accounting_firm: firm, company: company) }

  it "lets the administrator manage the team, but not their own access (D-584)" do
    accountant = create(:membership, organization: firm, roles: %w[accountant])
    own = Membership.find_by!(user: admin, organization: firm)

    expect(ability).to be_able_to(:invite, Membership.new(organization: firm))
    expect(ability).to be_able_to(:revoke, accountant)
    expect(ability).not_to be_able_to(:revoke, own)
    expect(ability).not_to be_able_to(:correct_contact, accountant)
  end

  it "resets the MFA only of accountants without access elsewhere (RN-02-044, D-582)" do
    accountant = create(:membership, organization: firm, roles: %w[accountant])
    other_admin = create(:membership, organization: firm, roles: %w[firm_admin])
    elsewhere = create(:membership, organization: firm, roles: %w[accountant])
    create(:membership, user: elsewhere.user, organization: create(:company), roles: %w[manager])

    expect(ability).to be_able_to(:reset_mfa, accountant)
    expect(ability).not_to be_able_to(:reset_mfa, other_admin)
    expect(ability).not_to be_able_to(:reset_mfa, elsewhere)
  end

  it "answers only this brand's pending requests (D-586, D-590)" do
    other_company = create(:company, partner: partner)
    pending = create(:accounting_firm_company, accounting_firm: firm, company: other_company, status: "pending")
    foreign = create(:accounting_firm_company, accounting_firm: firm, company: create(:company, :with_partner), status: "pending")

    expect(ability).to be_able_to(:accept, pending)
    expect(ability).not_to be_able_to(:accept, foreign)
  end

  it "gives nothing at a brand the firm does not serve" do
    other_brand = create(:brand, owner: create(:partner))

    expect(described_class.new(admin, other_brand)).not_to be_able_to(:read, :firm_panel)
  end
end
