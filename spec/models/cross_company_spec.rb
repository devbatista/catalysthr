require "rails_helper"

# Spec 01, RN-01-011 (P-01-06): the single point that reads more than one company.
RSpec.describe CrossCompany do
  before(:all) do
    Object.const_set("CrossCompanyProbe", Class.new(ApplicationRecord) {
      self.table_name = "cross_company_probes"
      acts_as_tenant :company
    })
  end

  after(:all) { Object.send(:remove_const, :CrossCompanyProbe) }

  before do
    ActiveRecord::Base.connection.create_table(:cross_company_probes) do |t|
      t.references :company, null: false
      t.string :name
    end
    CrossCompanyProbe.reset_column_information
  end

  let(:partner) { create(:partner) }
  let(:brand) { create(:brand, owner: partner) }
  let(:padaria) { create(:company, partner: partner) }
  let(:transportes) { create(:company, partner: partner) }
  let(:outsider) { create(:company) }

  def probe(company, name)
    ActsAsTenant.with_tenant(company) { CrossCompanyProbe.create!(name: name) }
  end

  it "reads only the given companies, without a current company" do
    probe(padaria, "a")
    probe(transportes, "b")
    probe(outsider, "c")

    names = described_class.scope(CrossCompanyProbe, Company.where(id: [ padaria.id, transportes.id ])).order(:name).pluck(:name)

    expect(names).to eq(%w[a b])
  end

  it "refuses a model that is not company-owned" do
    expect { described_class.scope(User, Company.all) }.to raise_error(ArgumentError)
  end

  it "gives the partner's administrator all the companies and the consultant the assigned ones (D-052)" do
    admin = create(:membership, organization: partner, roles: %w[partner_admin]).user
    consultant = create(:membership, organization: partner, roles: %w[consultant])
    consultant.partner_membership_companies.create!(company: padaria)
    transportes

    expect(described_class.companies_for(admin, brand: brand)).to contain_exactly(padaria, transportes)
    expect(described_class.companies_for(consultant.user, brand: brand)).to contain_exactly(padaria)
    expect(described_class.companies_for(create(:user), brand: brand)).to be_empty
  end

  it "is the only place in the code that switches the tenant off" do
    offenders = Dir[Rails.root.join("{app,lib}/**/*.rb")].reject { |path| path.end_with?("app/models/cross_company.rb") }
      .select { |path| File.read(path).match?(/without_tenant|current_tenant\s*=\s*nil/) }

    expect(offenders).to be_empty
  end
end
