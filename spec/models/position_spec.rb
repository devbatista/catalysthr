require "rails_helper"

# Spec 04, RN-04-030 to RN-04-032 (D-204, P-04-13).
RSpec.describe Position do
  let(:company) { create(:company) }

  around { |example| ActsAsTenant.with_tenant(company) { example.run } }

  before { CboOccupation.create!(code: "252405", title: "Analista de recursos humanos") }

  it "takes only a code of the official CBO (RN-04-031)" do
    expect(described_class.new(name: "Analista de RH", cbo_code: "2524-05")).to be_valid
    position = described_class.new(name: "Inventado", cbo_code: "999999")
    expect(position).not_to be_valid
    expect(position.errors[:cbo_code]).to include("não está na tabela oficial da CBO")
  end

  it "keeps a code that later left the table" do
    position = described_class.create!(name: "Analista de RH", cbo_code: "252405")
    CboOccupation.where(code: "252405").update_all(active: false)

    expect(position.reload.update(name: "Analista de pessoas")).to be(true)
  end

  it "has an optional range in cents, with the maximum not below the minimum (RN-04-032)" do
    position = described_class.new(name: "Analista de RH", cbo_code: "252405", salary_min_cents: 300_000, salary_max_cents: 250_000)
    expect(position).not_to be_valid

    position.salary_max_cents = 500_000
    expect(position.within_range?(250_000)).to be(false)
    expect(position.within_range?(400_000)).to be(true)
  end
end
