require "rails_helper"

# Spec 03, section 4.2 and RN-03-012; D-582.
RSpec.describe CompanyAbility do
  let(:company) { create(:company) }
  let(:hr_admin) { create(:membership, organization: company, roles: %w[hr_admin]).user }
  let(:ability) { Ability.new(hr_admin, area: :panel, company: company) }

  it "lets the HR administrator manage the company's users, but not their own access" do
    analyst = create(:membership, organization: company, roles: %w[hr_analyst])
    own = Membership.find_by!(user: hr_admin, organization: company)

    expect(ability).to be_able_to(:invite, Membership)
    expect(ability).to be_able_to(:update, analyst)
    expect(ability).to be_able_to(:revoke, analyst)
    expect(ability).not_to be_able_to(:update, own)
    expect(ability).not_to be_able_to(:revoke, own)
  end

  it "does not reach another company's memberships" do
    other = create(:membership, organization: create(:company))

    expect(ability).not_to be_able_to(:update, other)
    expect(Membership.accessible_by(ability)).not_to include(other)
  end

  it "resets the MFA only of the HR, and only of who has no access elsewhere (RN-02-044, D-582)" do
    analyst = create(:membership, organization: company, roles: %w[hr_analyst])
    manager = create(:membership, organization: company, roles: %w[manager])
    analyst_elsewhere = create(:membership, organization: company, roles: %w[hr_analyst])
    create(:membership, user: analyst_elsewhere.user, organization: create(:company), roles: %w[hr_admin])

    expect(ability).to be_able_to(:reset_mfa, analyst)
    expect(ability).not_to be_able_to(:reset_mfa, manager)
    expect(ability).not_to be_able_to(:reset_mfa, analyst_elsewhere)
    expect(ability).to be_able_to(:correct_contact, manager)
    expect(ability).not_to be_able_to(:correct_contact, analyst_elsewhere)
  end

  it "still counts a membership elsewhere that is only invited or suspended, but not a revoked one" do
    analyst = create(:membership, organization: company, roles: %w[hr_analyst])
    other = create(:membership, user: analyst.user, organization: create(:company), status: "invited")
    expect(ability).not_to be_able_to(:correct_contact, analyst)

    other.update!(status: "revoked")
    expect(ability).to be_able_to(:correct_contact, analyst)
  end

  it "gives nothing to analysts, managers and read-only memberships" do
    %w[hr_analyst manager].each do |role|
      user = create(:membership, organization: company, roles: [ role ]).user
      expect(Ability.new(user, area: :panel, company: company)).not_to be_able_to(:read, Membership), role
    end

    read_only = create(:membership, organization: company, roles: %w[hr_admin], status: "read_only").user
    expect(Ability.new(read_only, area: :panel, company: company)).not_to be_able_to(:invite, Membership)
  end
end
