require "rails_helper"

# Spec 04, RN-04-051 and RN-04-054 (CA-04-006, D-604).
RSpec.describe EmploymentRegistration do
  let(:company) { create(:company) }
  let(:hr_admin) { create(:membership, organization: company, roles: %w[hr_admin]).user }
  let(:position) { create_position(company) }
  let(:intern) do
    register_employee(company, by: hr_admin, position: position, kind: "intern", salary: "1.200,00", weekly_hours: "30",
      started_on: Date.new(2026, 2, 1))
  end

  around { |example| travel_to(Time.zone.local(2026, 10, 17, 10)) { example.run } }

  def in_company(&) = ActsAsTenant.with_tenant(company, &)

  it "converts the intern: the internship ends the day before and a CLT employment starts (CA-04-006, D-604)" do
    internship = in_company { intern.employments.sole }
    form = in_company { described_class.conversion_of(internship, company: company) }
    expect(form).to have_attributes(kind: "clt", registration_number: "2", unit_id: company.headquarters.id, weekly_hours: 30)

    form.assign_attributes(started_on: "2026-10-01", position_id: position.id, salary: "2.400,00")
    expect(in_company { form.save(profile: intern, by: hr_admin, converting: internship) }).to be(true)

    in_company do
      expect(internship.reload).to have_attributes(status: "terminated", ended_on: Date.new(2026, 9, 30), termination_reason: "conversion")
      clt = intern.employments.where(kind: "clt").sole
      expect(clt).to have_attributes(registration_number: "2", status: "active", started_on: Date.new(2026, 10, 1))
      expect(clt.revisions.sole).to have_attributes(salary_cents: 240_000, reason: "admission")
      expect(intern.employments.count).to eq(2)
    end
    expect(AccessEvent.find_by!(action: "intern_converted")).to have_attributes(subject_type: "Employment", user: hr_admin)
  end

  it "converts only an open internship, to a later date" do
    internship = in_company { intern.employments.sole }
    form = described_class.new(kind: "clt", registration_number: "9", started_on: "2026-02-01", position_id: position.id,
      unit_id: company.headquarters.id, salary: "2.400,00")

    expect(in_company { form.save(profile: intern, by: hr_admin, converting: internship) }).to be(false)
    expect(form.errors[:started_on]).to include("precisa ser depois do início do estágio")
    expect(in_company { internship.reload }).to be_active
  end

  it "adds a second employment with its own registration number (RN-04-051)" do
    form = described_class.new(kind: "contractor", registration_number: "PJ-1", started_on: "2026-09-01", position_id: position.id,
      unit_id: company.headquarters.id, salary: "5.000,00")

    expect(in_company { form.save(profile: intern, by: hr_admin) }).to be(true)
    expect(in_company { intern.employments.open.count }).to eq(2)
  end
end
