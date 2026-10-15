require "rails_helper"

RSpec.describe Membership do
  it "accepts more than one role in the same company (D-051)" do
    expect(build(:membership, roles: %w[manager employee])).to be_valid
  end

  it "only accepts the roles of its kind of organization (P-02-02)" do
    membership = build(:membership, roles: %w[hr_admin consultant])

    expect(membership).to be_invalid
    expect(membership.errors[:roles]).to include("têm um perfil que não existe neste tipo de organização")
    expect(build(:membership, organization: create(:partner), roles: %w[partner_admin consultant])).to be_valid
  end

  it "needs at least one role" do
    expect(build(:membership, roles: [ "" ])).to be_invalid
  end

  it "does not let the client's manager hold other roles in the company (P-02-38)" do
    membership = build(:membership, roles: %w[client_manager employee])

    expect(membership).to be_invalid
    expect(membership.errors[:roles]).to include("do gestor do cliente não podem incluir outros perfis da empresa")
    expect(build(:membership, roles: %w[client_manager])).to be_valid
  end

  it "keeps one membership per person and organization" do
    existing = create(:membership)

    expect(build(:membership, user: existing.user, organization: existing.organization)).to be_invalid
  end

  it "starts invited (RN-02-060)" do
    expect(described_class.new.status).to eq("invited")
  end

  describe ".for_brand (RN-01-002)" do
    it "returns nothing for a partner's company brand, which has no subdomain of its own (D-154)" do
      company = create(:company, :with_partner)
      create(:membership, organization: company)

      expect(described_class.for_brand(create(:brand, owner: company))).to be_empty
    end
  end
end
