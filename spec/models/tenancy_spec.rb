require "rails_helper"

# Spec 01, RN-01-010 and RN-01-012 (CA-01-005). No company-owned model exists yet,
# so the spec builds one on a table created inside the test transaction.
RSpec.describe "Company isolation" do
  before(:all) do
    stub_const_name = "TenancyProbe"
    Object.const_set(stub_const_name, Class.new(ApplicationRecord) {
      self.table_name = "tenancy_probes"
      acts_as_tenant :company
    })

    Object.const_set("TenancyProbeJob", Class.new(ApplicationJob) {
      def perform(name)
        TenancyProbe.create!(name: name)
      end
    })
  end

  after(:all) do
    Object.send(:remove_const, :TenancyProbe)
    Object.send(:remove_const, :TenancyProbeJob)
  end

  before do
    ActiveRecord::Base.connection.create_table(:tenancy_probes, id: :uuid, default: -> { "uuidv7()" }) do |t|
      t.references :company, type: :uuid, null: false
      t.string :name
    end
    TenancyProbe.reset_column_information
  end

  let(:company_a) { create(:company) }
  let(:company_b) { create(:company) }

  it "raises when a company-owned model is queried without a current company" do
    expect { TenancyProbe.count }.to raise_error(ActsAsTenant::Errors::NoTenantSet)
  end

  it "only reads and writes the current company's records" do
    ActsAsTenant.with_tenant(company_a) { TenancyProbe.create!(name: "a") }
    ActsAsTenant.with_tenant(company_b) { TenancyProbe.create!(name: "b") }

    ActsAsTenant.with_tenant(company_a) do
      expect(TenancyProbe.pluck(:name)).to eq([ "a" ])
      expect(TenancyProbe.create!(name: "a2").company_id).to eq(company_a.id)
    end
  end

  describe "jobs (CA-01-005)", type: :job do
    include ActiveJob::TestHelper

    it "run with the company that enqueued them" do
      ActsAsTenant.with_tenant(company_a) { TenancyProbeJob.perform_later("job") }
      perform_enqueued_jobs

      ActsAsTenant.with_tenant(company_a) { expect(TenancyProbe.pluck(:name)).to eq([ "job" ]) }
      ActsAsTenant.with_tenant(company_b) { expect(TenancyProbe.count).to eq(0) }
    end

    it "raise when enqueued without a company" do
      TenancyProbeJob.perform_later("orphan")

      expect { perform_enqueued_jobs }.to raise_error(ActsAsTenant::Errors::NoTenantSet)
    end
  end
end
