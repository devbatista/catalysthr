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

  describe "the company's people (spec 03, section 4.3)" do
    let(:position) { create_position(company) }
    let(:branch) { ActsAsTenant.with_tenant(company) { Unit.create!(name: "Filial Bento") } }
    let!(:at_headquarters) { register_employee(company, by: hr_admin, position: position, name: "Ana Lima") }
    let!(:at_branch) { register_employee(company, by: hr_admin, position: position, name: "Bruno Reis", unit: branch) }

    def ability_for(membership) = Ability.new(membership.user, area: :panel, company: company)

    def people(ability) = ActsAsTenant.with_tenant(company) { WorkerProfile.accessible_by(ability).to_a }

    it "gives the HR administrator every person, with pay, and the registration (T)" do
      expect(ability).to be_able_to(:create, WorkerProfile)
      expect(ability).to be_able_to(:read_pay, at_branch)
      expect(people(ability)).to contain_exactly(at_headquarters, at_branch)
    end

    it "gives the HR analyst the people of their units, with pay only with the payroll module (U, P-03-16)" do
      analyst = create(:membership, organization: company, roles: %w[hr_analyst], status: "active")
      Memberships::AssignUnits.call(membership: analyst, unit_ids: [ branch.id ], by: hr_admin)

      analyst_ability = ability_for(analyst)
      expect(people(analyst_ability)).to contain_exactly(at_branch)
      expect(analyst_ability).to be_able_to(:update, at_branch)
      expect(analyst_ability).to be_able_to(:read_health, at_branch)
      expect(analyst_ability).not_to be_able_to(:read_pay, at_branch)
      expect(analyst_ability).not_to be_able_to(:create, WorkerProfile)

      analyst.update!(enabled_modules: %w[folha])
      contract_for(company, modules: %w[folha])
      company.reload
      expect(ability_for(analyst)).to be_able_to(:read_pay, at_branch)
    end

    it "counts a released module only when the contract has it (P-03-12, D-616)" do
      analyst = create(:membership, organization: company, roles: %w[hr_analyst], status: "active", enabled_modules: %w[folha])
      Memberships::AssignUnits.call(membership: analyst, unit_ids: [ branch.id ], by: hr_admin)
      expect(ability_for(analyst)).not_to be_able_to(:read_pay, at_branch)

      subscription = contract_for(company, modules: %w[ponto])
      company.reload
      expect(ability_for(analyst)).not_to be_able_to(:read_pay, at_branch)

      subscription.items.create!(kind: "module", module: "folha", starts_on: Date.current)
      company.reload
      expect(ability_for(analyst)).to be_able_to(:read_pay, at_branch)

      subscription.update!(status: "closed")
      company.reload
      expect(ability_for(analyst)).not_to be_able_to(:read_pay, at_branch)
    end

    it "gives the partner's consultant a module only when the partner turned it on for the company (RN-19-012, D-616)" do
      partner = create(:partner)
      company.update!(partner: partner)
      consultant = create(:membership, organization: partner, roles: %w[consultant], status: "active", enabled_modules: %w[folha])
      consultant.partner_membership_companies.create!(company: company)
      contract_for(partner, modules: %w[folha])
      company.reload
      expect(ability_for(consultant)).not_to be_able_to(:read_pay, at_branch)

      turn_on_modules(company, %w[folha])
      company.reload
      expect(ability_for(consultant)).to be_able_to(:read_pay, at_branch)
    end

    it "gives the manager the basic data of the team only (E)" do
      manager = create(:membership, organization: company, roles: %w[manager], status: "active")
      ActsAsTenant.with_tenant(company) do
        department = Department.create!(unit: branch, name: "Logística")
        department.department_managers.create!(membership: manager)
        at_branch.employments.sole.revisions.sole.update_columns(department_id: department.id)
      end

      manager_ability = ability_for(manager)
      expect(people(manager_ability)).to contain_exactly(at_branch)
      expect(manager_ability).not_to be_able_to(:read_personal, at_branch)
      expect(manager_ability).not_to be_able_to(:read_pay, at_branch)
      expect(manager_ability).not_to be_able_to(:update, at_branch)
    end
  end
end
