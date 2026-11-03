require "rails_helper"

# Spec 08, section 6, and spec 03, section 4.5 (D-642): who reaches each folder and each
# category. Health is only for the HR (P-03-17, P-03-18, CA-08-009) and the payroll's only
# for who reads pay (P-03-16).
RSpec.describe "Document permissions" do
  let(:partner) { create(:partner) }
  let(:brand) { create(:brand, owner: partner) }
  let(:company) { create(:company, partner: partner) }
  let(:hr_user) { create(:user) }
  let!(:hr) { create(:membership, user: hr_user, organization: company, roles: %w[hr_admin]) }
  let(:branch) { in_company { Unit.create!(name: "Filial Bento") } }
  let(:position) { create_position(company) }
  let(:at_headquarters) { register_employee(company, by: hr_user, position: position, name: "Ana Souza") }
  let(:at_branch) { register_employee(company, by: hr_user, position: position, name: "Marcos Teles", unit: branch) }

  before { load_platform_document_types }

  def in_company(&) = ActsAsTenant.with_tenant(company, &)

  def document(profile, code)
    in_company { Document.create!(worker_profile: profile, document_type: DocumentType.find_by!(code: code)) }
  end

  def company_ability(membership) = Ability.new(membership.user, area: :panel, company: company)

  it "gives the HR administrator every folder and category" do
    ability = company_ability(hr)

    %w[rg aso_periodic bank_account_proof].each do |code|
      expect(ability).to be_able_to(:review, document(at_branch, code))
    end
  end

  describe "the HR analyst (U · M)" do
    let(:analyst) { create(:membership, organization: company, roles: %w[hr_analyst], status: "active", enabled_modules: %w[documentos]) }

    before { Memberships::AssignUnits.call(membership: analyst, unit_ids: [ branch.id ], by: hr_user) }

    it "reaches only the folders of their units, health included (P-03-17)" do
      rg, aso, elsewhere = document(at_branch, "rg"), document(at_branch, "aso_periodic"), document(at_headquarters, "rg")
      ability = company_ability(analyst)

      expect(ability).to be_able_to(:review, rg)
      expect(ability).to be_able_to(:read, aso)
      expect(ability).not_to be_able_to(:read, elsewhere)
      expect(in_company { Document.accessible_by(ability).map(&:worker_profile_id).uniq }).to eq([ at_branch.id ])
    end

    it "reads the payroll's category only with the payroll module (P-03-16)" do
      proof = document(at_branch, "bank_account_proof")
      expect(company_ability(analyst)).not_to be_able_to(:read, proof)

      analyst.update!(enabled_modules: %w[documentos folha])
      expect(company_ability(analyst)).to be_able_to(:read, proof)
    end

    it "reaches no folder without the documents module (spec 03, section 2.3)" do
      analyst.update!(enabled_modules: %w[admissao])

      expect(company_ability(analyst)).not_to be_able_to(:read, document(at_branch, "rg"))
    end
  end

  it "gives the manager no folder, even of the team (spec 03, section 4.5)" do
    manager = create(:membership, organization: company, roles: %w[manager], status: "active")

    expect(company_ability(manager)).not_to be_able_to(:read, document(at_branch, "rg"))
  end

  it "lets the accounting firm read the folder, without health (D-193, P-03-18, CA-08-009)" do
    firm = create(:accounting_firm)
    create(:accounting_firm_company, accounting_firm: firm, company: company)
    accountant = create(:membership, organization: firm, roles: %w[accountant]).user
    ability = AccountingFirmAbility.new(accountant, brand)

    expect(ability).to be_able_to(:read, document(at_branch, "rg"))
    expect(ability).to be_able_to(:read, document(at_branch, "bank_account_proof"))
    expect(ability).not_to be_able_to(:read, document(at_branch, "aso_periodic"))
    expect(ability).not_to be_able_to(:review, document(at_branch, "rg"))

    other = create(:company, partner: partner)
    other_hr = create(:membership, organization: other, roles: %w[hr_admin]).user
    outsider = register_employee(other, by: other_hr, position: create_position(other), name: "Rita Souza")
    foreign = ActsAsTenant.with_tenant(other) { Document.create!(worker_profile: outsider, document_type: DocumentType.find_by!(code: "rg")) }
    expect(ability).not_to be_able_to(:read, foreign)
  end
end
