require "rails_helper"

# Spec 03, section 4.1; D-185, D-581, D-582, P-03-03.
RSpec.describe PlatformAbility do
  let(:client) { create(:user) }
  let(:team_member) { create(:user, platform_role: "finance") }

  it "gives the support the impersonate, the entry into direct companies and the users' contact and MFA" do
    ability = described_class.new(create(:user, platform_role: "support"))

    expect(ability).to be_able_to(:create, ImpersonationSession)
    expect(ability).to be_able_to(:create, SupportAccess)
    expect(ability).to be_able_to(:reset_mfa, client)
    expect(ability).not_to be_able_to(:reset_mfa, team_member)
  end

  it "keeps the superadmin out of the companies, except by impersonate (P-03-03)" do
    ability = described_class.new(create(:user, platform_role: "superadmin"))

    expect(ability).to be_able_to(:create, ImpersonationSession)
    expect(ability).not_to be_able_to(:create, SupportAccess)
    expect(ability).to be_able_to(:correct_contact, client)
  end

  it "gives finance none of these" do
    ability = described_class.new(team_member)

    expect(ability).not_to be_able_to(:create, ImpersonationSession)
    expect(ability).not_to be_able_to(:create, SupportAccess)
    expect(ability).not_to be_able_to(:reset_mfa, client)
  end

  it "gives plans, versions and add-on prices to the superadmin and finance only (spec 03, section 4.1, D-611)" do
    %w[superadmin finance].each do |role|
      ability = described_class.new(create(:user, platform_role: role))

      expect(ability).to be_able_to(:create, Plan)
      expect(ability).to be_able_to(:update, Plan)
      expect(ability).to be_able_to(:create, PlanVersion)
      expect(ability).to be_able_to(:create, AddOnPrice)
      expect(ability).not_to be_able_to(:update, PlanVersion)
      expect(ability).not_to be_able_to(:update, AddOnPrice)
    end

    support = described_class.new(create(:user, platform_role: "support"))
    expect(support).not_to be_able_to(:read, Plan)
    expect(support).not_to be_able_to(:create, PlanVersion)
  end
end
