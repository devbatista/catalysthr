require "rails_helper"

# Spec 03, section 4.1; P-03-01, P-03-35, D-582, D-584, D-585.
RSpec.describe PartnerAbility do
  let(:partner) { create(:partner) }
  let(:company) { create(:company, partner: partner) }
  let(:admin) { create(:membership, organization: partner, roles: %w[partner_admin]).user }
  let(:ability) { described_class.new(admin, partner) }

  it "lets the administrator manage the team, but not their own access (D-584)" do
    consultant = create(:membership, organization: partner, roles: %w[consultant])
    own = Membership.find_by!(user: admin, organization: partner)

    expect(ability).to be_able_to(:invite, Membership.new(organization: partner))
    expect(ability).to be_able_to(:update, consultant)
    expect(ability).to be_able_to(:revoke, consultant)
    expect(ability).to be_able_to(:reset_mfa, consultant)
    expect(ability).not_to be_able_to(:update, own)
    expect(ability).not_to be_able_to(:revoke, own)
  end

  it "does not reach another partner's team" do
    other = create(:membership, organization: create(:partner), roles: %w[consultant])

    expect(ability).not_to be_able_to(:invite, Membership.new(organization: other.organization))
    expect(ability).not_to be_able_to(:update, other)
    expect(Membership.accessible_by(ability, :read)).not_to include(other)
  end

  it "leaves the contact and the MFA of who has access elsewhere to the support (D-582)" do
    consultant = create(:membership, organization: partner, roles: %w[consultant])
    create(:membership, user: consultant.user, organization: create(:company), roles: %w[hr_admin])

    expect(ability).to be_able_to(:update, consultant)
    expect(ability).not_to be_able_to(:reset_mfa, consultant)
    expect(ability).not_to be_able_to(:correct_contact, consultant)
  end

  it "changes the HR administrators of the partner's companies only (P-03-35, D-585)" do
    hr_admin = create(:membership, organization: company, roles: %w[hr_admin])
    analyst = create(:membership, organization: company, roles: %w[hr_analyst])
    elsewhere = create(:membership, organization: create(:company, :with_partner), roles: %w[hr_admin])

    expect(ability).to be_able_to(:invite_hr_admin, Membership.new(organization: company, roles: %w[hr_admin]))
    expect(ability).to be_able_to(:change_hr_admin, hr_admin)
    expect(ability).not_to be_able_to(:change_hr_admin, analyst)
    expect(ability).not_to be_able_to(:change_hr_admin, elsewhere)
    expect(ability).not_to be_able_to(:update, hr_admin)
  end

  it "gives the consultant the panel, without the team or the companies' HR (P-03-01)" do
    consultant = create(:membership, organization: partner, roles: %w[consultant]).user
    ability = described_class.new(consultant, partner)

    expect(ability).to be_able_to(:read, :partner_panel)
    expect(ability).not_to be_able_to(:read, Membership.new(organization: partner))
    expect(ability).not_to be_able_to(:invite_hr_admin, Membership.new(organization: company, roles: %w[hr_admin]))
  end

  it "gives nothing to a suspended membership" do
    suspended = create(:membership, organization: partner, roles: %w[partner_admin], status: "suspended").user

    expect(described_class.new(suspended, partner)).not_to be_able_to(:read, :partner_panel)
  end
end
