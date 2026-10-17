require "rails_helper"

# Spec 04, RN-04-040, RN-04-051, RN-04-052 (CA-04-005, CA-04-007, CA-04-010; D-600, D-602).
RSpec.describe EmployeeRegistration do
  let(:company) { create(:company) }
  let(:hr_admin) { create(:membership, organization: company, roles: %w[hr_admin]).user }
  let(:position) { create_position(company, salary_min_cents: 200_000, salary_max_cents: 350_000) }

  def in_company(target = company, &) = ActsAsTenant.with_tenant(target, &)

  def registration(**attributes)
    described_class.new({
      name: "Ana Lima", cpf: "529.982.247-25", birth_date: "1990-05-10", email: "ana@example.com",
      registration_number: "1", started_on: "2026-03-01", position_id: position.id,
      unit_id: company.headquarters.id, salary: "2.500,00"
    }.merge(attributes))
  end

  it "creates the person, the employee membership without invitation, the record, the employment and the first revision" do
    form = registration(social_name: "Ana")

    expect(in_company { form.save(company: company, by: hr_admin) }).to be(true)

    user = User.find_by!(cpf: "52998224725")
    membership = Membership.find_by!(user: user, organization: company)
    expect(membership).to have_attributes(roles: %w[employee], status: "invited", invitation_token_digest: nil)
    in_company do
      employment = form.profile.employments.sole
      expect(form.profile).to have_attributes(membership: membership, social_name: "Ana")
      expect(employment).to have_attributes(kind: "clt", category: "standard", registration_number: "1", status: "active")
      expect(employment.revisions.sole).to have_attributes(reason: "admission", effective_on: Date.new(2026, 3, 1),
        salary_cents: 250_000, salary_unit: "month", cbo_code: "252405", created_by: hr_admin)
    end
    expect(company.reload.next_registration_number).to eq(2)
    expect(AccessEvent.find_by!(action: "employee_registered")).to have_attributes(kind: "admin", user: hr_admin, subject: membership)
  end

  it "links a CPF that already has an account, keeping its name and contacts (D-602, CA-04-007)" do
    other = create(:company)
    person = create(:user, name: "Ana Souza Lima", cpf: "52998224725", email: "ana.souza@example.com")
    create(:membership, user: person, organization: other, roles: %w[employee])
    in_company(other) { WorkerProfile.create!(membership: Membership.find_by!(user: person), city: "Caxias do Sul") }

    form = registration(name: "Outro Nome", email: "outro@example.com")
    expect(in_company { form.save(company: company, by: hr_admin) }).to be(true)

    expect(form.existing_person).to be(true)
    expect(person.reload).to have_attributes(name: "Ana Souza Lima", email: "ana.souza@example.com")
    in_company { form.profile.update!(city: "Bento Gonçalves") }
    expect(in_company(other) { WorkerProfile.sole.city }).to eq("Caxias do Sul")
  end

  it "adds the employee role to someone who already has access to the company" do
    manager = create(:membership, organization: company, roles: %w[manager], status: "active")

    form = registration(cpf: manager.user.cpf)
    expect(in_company { form.save(company: company, by: hr_admin) }).to be(true)

    expect(manager.reload).to have_attributes(roles: %w[manager employee], status: "active")
  end

  it "refuses a person who already has a record in the company" do
    in_company { registration.save(company: company, by: hr_admin) }

    form = registration(registration_number: "2")
    expect(in_company { form.save(company: company, by: hr_admin) }).to be(false)
    expect(form.errors[:cpf]).to include("já tem ficha nesta empresa")
    expect(in_company { Employment.count }).to eq(1)
  end

  it "refuses a registration number used by an ended employment (CA-04-010)" do
    profile = register_employee(company, by: hr_admin, position: position, registration_number: "1050")
    in_company { profile.employments.sole.update!(status: "terminated", ended_on: Date.new(2026, 6, 30), termination_reason: "Pedido") }

    form = registration(registration_number: "1050")
    expect(in_company { form.save(company: company, by: hr_admin) }).to be(false)
    expect(form.errors[:registration_number]).to include("já foi usada por outro vínculo desta empresa, inclusive encerrado")
  end

  it "asks for the justification of a monthly salary out of the position's range (CA-04-005)" do
    form = registration(salary: "1.800,00")
    expect(in_company { form.save(company: company, by: hr_admin) }).to be(false)
    expect(form.errors[:justification].sole).to include("fora da faixa do cargo (R$ 2.000,00 a R$ 3.500,00)")
    expect(User.exists?(cpf: "52998224725")).to be(false)

    form = registration(salary: "1.800,00", justification: "Período de experiência")
    expect(in_company { form.save(company: company, by: hr_admin) }).to be(true)
  end

  it "leaves who has not started yet to the admission" do
    form = registration(started_on: Date.current + 1)

    expect(form.save(company: company, by: hr_admin)).to be(false)
    expect(form.errors[:started_on]).to include("não pode ser futura: quem ainda vai começar entra pela admissão")
  end

  it "suggests the next registration number, skipping the ones already used (RN-04-052, D-211)" do
    register_employee(company, by: hr_admin, position: position, registration_number: "1")
    register_employee(company, by: hr_admin, position: position, registration_number: "A-7")
    expect(company.reload.suggested_registration_number).to eq("2")

    register_employee(company, by: hr_admin, position: position, registration_number: "2")
    company.update!(next_registration_number: 1)
    expect(company.suggested_registration_number).to eq("3")
  end
end
