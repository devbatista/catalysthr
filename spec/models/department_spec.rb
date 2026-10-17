require "rails_helper"

# Spec 04, RN-04-020 to RN-04-025 (CA-04-002, CA-04-003, D-190, D-202, D-203).
RSpec.describe Department do
  let(:company) { create(:company) }

  around { |example| ActsAsTenant.with_tenant(company) { example.run } }

  let(:unit) { company.headquarters }
  let(:production) { described_class.create!(unit: unit, name: "Produção") }
  let(:machining) { described_class.create!(unit: unit, name: "Usinagem", parent: production) }

  def manager(name)
    user = create(:user, name: name)
    create(:membership, user: user, organization: company, roles: %w[manager], status: "active")
  end

  it "keeps the parent in the same unit and refuses cycles (RN-04-020)" do
    branch = Unit.create!(name: "Filial")
    other = described_class.create!(unit: branch, name: "Logística")

    expect(described_class.new(unit: unit, name: "X", parent: other)).not_to be_valid
    production.parent = machining
    expect(production).not_to be_valid
    expect(production.errors[:parent]).to include("não pode ser o próprio departamento nem um departamento abaixo dele")
  end

  it "takes only active managers of the company (RN-04-021, P-04-09)" do
    carlos = manager("Carlos Mendes")
    analyst = create(:membership, organization: company, roles: %w[hr_analyst], status: "active")
    outsider = create(:membership, organization: create(:company), roles: %w[manager], status: "active")

    expect(production.department_managers.create(membership: carlos)).to be_persisted
    expect(production.department_managers.create(membership: analyst)).not_to be_persisted
    expect(ActsAsTenant.without_tenant { production.department_managers.create(membership: outsider) }).not_to be_persisted
  end

  it "makes the subdepartments part of the manager's team (RN-04-022, CA-04-002)" do
    carlos = manager("Carlos Mendes")
    production.department_managers.create!(membership: carlos)
    machining
    described_class.create!(unit: unit, name: "Administrativo")

    expect(described_class.team_ids_for(carlos)).to contain_exactly(production.id, machining.id)
  end

  it "sends a manager's own approvals to the nearest department above with managers (RN-04-024, CA-04-003)" do
    first, second = manager("Carlos Mendes"), manager("Bianca Lopes")
    production.department_managers.create!(membership: first)
    production.department_managers.create!(membership: second)
    lathe = described_class.create!(unit: unit, name: "Tornearia", parent: machining)

    expect(lathe.managers_above).to contain_exactly(first, second)
    expect(production.managers_above).to be_empty
  end

  it "is inactivated only after its subdepartments (RN-04-025)" do
    machining

    expect(production.update(status: "inactive")).to be(false)
    machining.update!(status: "inactive")
    expect(production.reload.update(status: "inactive")).to be(true)
  end

  it "stops counting a manager who loses the role or the access (RN-04-021)" do
    carlos = manager("Carlos Mendes")
    production.department_managers.create!(membership: carlos)

    Memberships::UpdateAccess.call(membership: carlos, roles: %w[employee], enabled_modules: [], by: create(:user))

    expect(production.managers.reload).to be_empty
  end
end
