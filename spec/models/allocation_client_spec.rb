require "rails_helper"

# Spec 04, RN-04-090 to RN-04-096 (CA-04-012, CA-04-013, D-570), and spec 02, RN-02-064.
RSpec.describe AllocationClient do
  let(:company) { create(:company, uses_allocation_clients: true) }
  let(:hr_admin) { create(:membership, organization: company, roles: %w[hr_admin]).user }
  let(:position) { create_position(company) }

  around { |example| travel_to(Time.zone.local(2026, 10, 17, 10)) { example.run } }

  def in_company(&) = ActsAsTenant.with_tenant(company, &)

  def client(name, **attributes) = in_company { described_class.create!(name: name, **attributes) }

  def client_manager(name, *clients)
    membership = create(:membership, organization: company, roles: %w[client_manager], user: create(:user, name: name))
    in_company { clients.each { |item| item.allocation_client_managers.create!(membership: membership) } }
    membership
  end

  def ability_of(membership) = Ability.new(membership.user, area: :panel, company: company.reload)

  def team(membership) = in_company { WorkerProfile.accessible_by(ability_of(membership)).to_a }

  it "takes an optional document, valid and unique in the company (RN-04-091)" do
    client("Cliente X", document_type: "cnpj", document: "11.222.333/0001-81")

    in_company do
      expect(described_class.new(name: "Y", document_type: "cnpj", document: "11222333000181")).not_to be_valid
      expect(described_class.new(name: "Z", document_type: "cpf", document: "111.111.111-11")).not_to be_valid
      expect(described_class.new(name: "W")).to be_valid
    end
  end

  it "moves Ana from the managers of X to those of Y on the revision's date (CA-04-012)" do
    x = client("Cliente X")
    y = client("Cliente Y")
    manager_x = client_manager("Gestora X", x)
    manager_y = client_manager("Gestor Y", y)
    ana = register_employee(company, by: hr_admin, position: position, name: "Ana Lima", allocation_client_id: x.id)
    in_company do
      employment = ana.employments.sole
      employment.revisions.create!(effective_on: Date.new(2026, 12, 1), reason: "transfer", position: position,
        unit: company.headquarters, allocation_client: y, salary_cents: 200_000, salary_unit: "month", created_by: hr_admin)
    end

    expect(team(manager_x)).to eq([ ana ])
    expect(team(manager_y)).to be_empty

    travel_to Time.zone.local(2026, 12, 1, 8)
    expect(team(manager_x)).to be_empty
    expect(team(manager_y)).to eq([ ana ])
    expect(ability_of(manager_y)).not_to be_able_to(:read_personal, ana)
  end

  it "is not inactivated with an open employment, even a pending one (CA-04-013)" do
    x = client("Cliente X")
    ana = register_employee(company, by: hr_admin, position: position, allocation_client_id: x.id)
    in_company { ana.employments.sole.update!(status: "pending") }

    in_company do
      expect(x.update(status: "inactive")).to be(false)
      expect(x.errors[:status]).to include("inativo só sem colaboradores alocados, hoje ou agendados")
    end
  end

  it "takes the access away from managers left without an active client (RN-02-064)" do
    x = client("Cliente X")
    y = client("Cliente Y")
    both = client_manager("Gestora XY", x, y)
    only_x = client_manager("Gestor X", x)

    in_company { x.update!(status: "inactive") }
    AllocationClients.release_managers!(company, by: hr_admin)

    expect(only_x.reload).to be_revoked
    expect(both.reload).to be_active
    expect(in_company { AllocationClientManager.where(membership: only_x) }).to be_empty
  end

  it "turns off only without allocated people, and then removes every client manager (RN-04-090)" do
    x = client("Cliente X")
    manager = client_manager("Gestora X", x)
    ana = register_employee(company, by: hr_admin, position: position, allocation_client_id: x.id)

    expect(company.reload.update(uses_allocation_clients: false)).to be(false)
    expect(company.errors[:uses_allocation_clients]).to be_present

    in_company { ana.employments.sole.update!(status: "terminated", ended_on: Date.current, termination_reason: "Pedido") }
    expect(company.reload.update(uses_allocation_clients: false)).to be(true)
    AllocationClients.release_managers!(company, by: hr_admin)
    expect(manager.reload).to be_revoked
  end

  it "takes no client on a revision while the company does not use them (RN-04-090)" do
    x = client("Cliente X")
    company.update!(uses_allocation_clients: false)

    expect { register_employee(company, by: hr_admin, position: position, allocation_client_id: x.id) }
      .to raise_error(/só vale quando a empresa usa clientes de alocação/)
  end
end
