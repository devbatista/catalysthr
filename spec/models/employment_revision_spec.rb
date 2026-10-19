require "rails_helper"

# Spec 04, RN-04-060 to RN-04-064 (CA-04-004, CA-04-005; D-086, D-207, D-603).
RSpec.describe EmploymentRevision do
  let(:company) { create(:company) }
  let(:hr_admin) { create(:membership, organization: company, roles: %w[hr_admin]).user }
  let(:position) { create_position(company, salary_min_cents: 200_000, salary_max_cents: 350_000) }
  let(:profile) { register_employee(company, by: hr_admin, position: position, salary: "2.000,00", started_on: Date.new(2026, 3, 1)) }
  let(:employment) { profile.employments.sole }

  around { |example| travel_to(Time.zone.local(2026, 10, 17, 10)) { example.run } }

  def in_company(&) = ActsAsTenant.with_tenant(company, &)

  def revise(effective_on, reason: "salary_change", **attributes)
    in_company do
      current = employment.reload.current_revision
      employment.revisions.create!(effective_on: effective_on, reason: reason, position: current.position, unit: current.unit,
        salary_cents: current.salary_cents, salary_unit: current.salary_unit, created_by: hr_admin, **attributes)
    end
  end

  it "applies a raise from its date and keeps it scheduled until then (CA-04-004)" do
    raise_revision = revise(Date.new(2026, 12, 1), salary_cents: 230_000)

    in_company do
      employment.reload
      expect(employment.revision_on(Date.new(2026, 11, 30)).salary_cents).to eq(200_000)
      expect(employment.revision_on(Date.new(2026, 12, 1)).salary_cents).to eq(230_000)
      expect(employment.current_revision.salary_cents).to eq(200_000)
      expect(employment.scheduled_revisions).to eq([ raise_revision ])
      expect(raise_revision).to be_future
    end
  end

  it "keeps a revision in force unchanged; a correction on the same date prevails (D-603)" do
    in_company do
      admission = employment.revisions.sole
      expect(admission.update(salary_cents: 210_000)).to be(false)
      expect(admission.errors[:base].sole).to include("já está em vigor")
      expect(admission.destroy).to be(false)
    end

    correction = revise(Date.new(2026, 3, 1), reason: "correction", salary_cents: 210_000)
    in_company { expect(employment.reload.current_revision).to eq(correction) }
  end

  it "lets a future revision be edited or deleted until its date (D-603)" do
    future = revise(Date.new(2026, 12, 1), salary_cents: 230_000)

    in_company do
      expect(future.update(salary_cents: 240_000)).to be(true)
      expect(future.destroy).to be_truthy
    end
  end

  it "warns about a retroactive revision, but not about the admission (RN-04-062)" do
    in_company { expect(employment.revisions.sole).not_to be_retroactive }
    expect(revise(Date.new(2026, 9, 1))).to be_retroactive
  end

  it "keeps the department in the revision's unit (RN-04-064)" do
    in_company do
      branch = Unit.create!(name: "Filial Bento")
      logistics = Department.create!(unit: branch, name: "Logística")
      revision = employment.revisions.new(effective_on: Date.new(2026, 12, 1), reason: "transfer", position: position,
        unit: company.headquarters, department: logistics, salary_cents: 200_000, salary_unit: "month", created_by: hr_admin)

      expect(revision).not_to be_valid
      expect(revision.errors[:department]).to include("precisa ser da unidade escolhida")
    end
  end

  it "compares only a monthly salary with the position's range (RN-04-032, D-603)" do
    in_company do
      hourly = employment.revisions.new(effective_on: Date.new(2026, 12, 1), reason: "salary_change", position: position,
        unit: company.headquarters, salary_cents: 1_500, salary_unit: "hour", created_by: hr_admin)
      expect(hourly).to be_valid

      hourly.salary_unit = "month"
      expect(hourly).not_to be_valid
      expect(hourly.errors[:justification]).to be_present
    end
  end

  it "keeps the salary encrypted and out of the versions (D-086)" do
    in_company do
      revision = employment.revisions.sole
      raw = described_class.connection.select_value("SELECT salary_cents FROM employment_revisions WHERE id = '#{revision.id}'")

      expect(raw).not_to include("200000")
      expect(revision.reload.salary_cents).to eq(200_000)
      expect(PaperTrail::Version.where(item: revision).map(&:object_changes).compact.flat_map(&:keys)).not_to include("salary_cents")
    end
  end

  it "picks, for each employment, the revision in force or, before the start, the first one (RN-04-061)" do
    future = revise(Date.new(2026, 12, 1), salary_cents: 230_000)

    in_company do
      expect(described_class.counting.pluck(:id)).to eq([ employment.revisions.first.id ])
      expect(described_class.counting(Date.new(2026, 12, 1)).pluck(:id)).to eq([ future.id ])
      expect(described_class.counting(Date.new(2026, 1, 1)).pluck(:id)).to eq([ employment.revisions.first.id ])
    end
  end
end
