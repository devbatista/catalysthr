require "rails_helper"

# Spec 04, RN-04-043 and RN-04-044 (CA-04-008, P-04-17, D-086, D-604).
RSpec.describe BankAccount do
  let(:company) { create(:company) }
  let(:hr_admin) { create(:membership, organization: company, roles: %w[hr_admin]).user }
  let(:profile) { register_employee(company, by: hr_admin, position: create_position(company)) }

  def in_company(&) = ActsAsTenant.with_tenant(company, &)

  def register(primary: true, **attributes)
    in_company { BankAccounts::Register.call(profile: profile, attributes: attributes, primary: primary, by: hr_admin) }
  end

  it "takes a bank account or a PIX key, not both, and checks the key by its type" do
    expect(register(bank_code: "1", branch: "1234", account_number: "12345-6", account_type: "checking").errors[:bank_code]).to be_present
    expect(register(bank_code: "001", pix_key_type: "email", pix_key: "ana@example.com").errors[:base]).to be_present
    expect(register(pix_key_type: "cpf", pix_key: "111.111.111-11").errors[:pix_key]).to be_present
    expect(register(pix_key_type: "email", pix_key: "Ana@Example.com")).to be_persisted
  end

  it "keeps a single active primary: a new one ends the previous, which stays as history (CA-04-008, D-604)" do
    first = register(bank_code: "001", branch: "1234", account_number: "12345-6", account_type: "checking")
    second = register(pix_key_type: "email", pix_key: "ana@example.com")

    in_company do
      expect(first.reload).to have_attributes(status: "ended", ended_on: Date.current)
      expect(second).to have_attributes(primary: true, status: "active", declared_by: hr_admin)
      expect(profile.bank_accounts.count).to eq(2)
    end
  end

  it "keeps the account number and the key encrypted and out of the versions (D-086)" do
    account = register(bank_code: "001", branch: "1234", account_number: "12345-6", account_type: "checking")
    raw = described_class.connection.select_value("SELECT account_number FROM bank_accounts WHERE id = '#{account.id}'")

    expect(raw).not_to include("123456")
    changes = PaperTrail::Version.where(item: account).filter_map(&:object_changes).flat_map(&:keys)
    expect(changes).not_to include("account_number", "pix_key")
  end

  it "ends a dependent instead of deleting it, with the CPF encrypted (RN-04-043, D-604)" do
    in_company do
      dependent = profile.dependents.create!(name: "Lia Lima", birth_date: Date.new(2018, 4, 2), relationship_type: "child",
        cpf: "529.982.247-25", irrf: true)
      raw = described_class.connection.select_value("SELECT cpf FROM dependents WHERE id = '#{dependent.id}'")
      expect(raw).not_to include("52998224725")

      dependent.end!(on: Date.new(2026, 10, 1))
      expect(dependent.reload).to have_attributes(status: "ended", ended_on: Date.new(2026, 10, 1))
      expect(profile.dependents.new(name: "X", birth_date: Date.current + 1, relationship_type: "child")).not_to be_valid
    end
  end
end
