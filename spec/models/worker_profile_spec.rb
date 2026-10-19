require "rails_helper"

# Spec 04, RN-04-041, RN-04-042, RN-04-053, RN-04-014, RN-04-025 (D-086, D-602).
RSpec.describe WorkerProfile do
  let(:company) { create(:company) }
  let(:hr_admin) { create(:membership, organization: company, roles: %w[hr_admin]).user }
  let(:position) { create_position(company) }
  let(:profile) { register_employee(company, by: hr_admin, position: position) }

  def in_company(&) = ActsAsTenant.with_tenant(company, &)

  it "keeps documents and the disability encrypted and out of the versions (RN-04-042, D-086)" do
    in_company do
      profile.update!(rg_number: "12.345.678-9", pis_nis: "120.12345.67-8", disability_types: %w[hearing],
        disability_rehabilitated: "1", disability_notes: "Usa aparelho auditivo")
      row = described_class.connection.select_one("SELECT rg_number, pis_nis, disability FROM worker_profiles WHERE id = '#{profile.id}'")

      expect(row.values.join).not_to include("123456789", "12012345678", "hearing", "aparelho")
      expect(profile.reload).to have_attributes(rg_number: "123456789", pis_nis: "12012345678",
        disability_types: %w[hearing], disability_rehabilitated: true, disability_notes: "Usa aparelho auditivo")
      changes = PaperTrail::Version.where(item: profile).filter_map(&:object_changes).flat_map(&:keys)
      expect(changes).not_to include("rg_number", "pis_nis", "disability")
    end
  end

  it "validates the list fields by the system's own values (D-602)" do
    in_company do
      profile.assign_attributes(marital_status: "casado", state: "XX", disability_types: %w[other])

      expect(profile).not_to be_valid
      expect(profile.errors.attribute_names).to include(:marital_status, :state, :disability_types)
    end
  end

  it "keeps only the details of the employment's kind, typed (RN-04-053, P-04-27)" do
    in_company do
      employment = profile.employments.sole
      employment.update!(details: { "contract_term" => "fixed", "contract_end_on" => "2027-02-28", "union_cnpj" => "11.222.333/0001-81",
        "assurance_clause" => "1", "school_name" => "Escola X" })

      expect(employment.details).to eq("contract_term" => "fixed", "contract_end_on" => "2027-02-28",
        "union_cnpj" => "11222333000181", "assurance_clause" => true)
      employment.details = { "contract_term" => "fixed" }
      expect(employment).not_to be_valid
      expect(employment.errors[:details_contract_end_on]).to be_present
    end
  end

  it "does not inactivate a unit or a department with an open employment (RN-04-014, RN-04-025)" do
    in_company do
      department = Department.create!(unit: company.headquarters, name: "Produção")
      branch = Unit.create!(name: "Filial")
      revision = profile.employments.sole.revisions.sole
      revision.update_columns(department_id: department.id, unit_id: branch.id)

      expect(branch.update(status: "inactive")).to be(false)
      expect(branch.errors[:status]).to include("inativa só sem vínculos ativos nela, hoje ou agendados")
      expect(department.update(status: "inactive")).to be(false)

      profile.employments.sole.update!(status: "terminated", ended_on: Date.current, termination_reason: "Pedido")
      expect(branch.update(status: "inactive")).to be(true)
    end
  end
end
