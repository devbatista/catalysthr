require "rails_helper"

# Spec 04, RN-04-010 to RN-04-014 (CA-04-001, D-201, D-600).
RSpec.describe Unit do
  let(:company) { create(:company, document: "11222333") }

  around { |example| ActsAsTenant.with_tenant(company) { example.run } }

  def unit(**attributes)
    described_class.new(name: "Filial Caxias", **attributes)
  end

  it "takes a branch's CNPJ with the company's root (RN-04-011)" do
    expect(unit(registration_type: "cnpj", registration_number: "11.222.333/0002-62")).to be_valid
  end

  it "refuses a branch's CNPJ with another root (CA-04-001)" do
    branch = unit(registration_type: "cnpj", registration_number: "11.444.777/0001-61")

    expect(branch).not_to be_valid
    expect(branch.errors[:registration_number]).to include("precisa ter a mesma raiz do CNPJ da empresa (11.222.333)")
  end

  it "refuses an invalid CNPJ, and a CNPJ for a person employer (D-200)" do
    expect(unit(registration_type: "cnpj", registration_number: "11222333000299")).not_to be_valid

    person = create(:company, employer_type: "person", document: "12345678909")
    ActsAsTenant.with_tenant(person) do
      site = unit(registration_type: "cnpj", registration_number: "11.222.333/0002-62")
      expect(site).not_to be_valid
      expect(site.errors[:registration_type]).to include("não pode ser CNPJ para empregador pessoa física; use CNO ou CAEPF")
      expect(unit(registration_type: "cno", registration_number: "123456789012")).to be_valid
    end
  end

  it "uses the headquarters' registration without its own (D-201)" do
    headquarters = company.headquarters
    headquarters.update!(registration_type: "cnpj", registration_number: "11222333000181")
    branch = described_class.create!(name: "Obra Centro")

    expect(branch.effective_registration).to eq(headquarters)
  end

  it "defaults to São Paulo's time zone and accepts only Brazil's (RN-04-013, P-04-07)" do
    expect(unit.time_zone).to eq("America/Sao_Paulo")
    expect(unit(time_zone: "America/Manaus")).to be_valid
    expect(unit(time_zone: "Europe/Lisbon")).not_to be_valid
  end

  it "never inactivates the headquarters (RN-04-010)" do
    headquarters = company.headquarters

    expect(headquarters.update(status: "inactive")).to be(false)
    expect(described_class.create!(name: "Filial").update(status: "inactive")).to be(true)
  end

  it "belongs to one company only (RN-01-010)" do
    other = create(:company)
    ActsAsTenant.with_tenant(other) { described_class.create!(name: "Filial de outra") }

    expect(described_class.pluck(:name)).to eq([ "Matriz" ])
  end
end
