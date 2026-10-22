require "rails_helper"

# Spec 20, block 20a (RN-20-046, CA-20-008, D-627): the restore drill records the time, the
# size and the checks of the latest dump restored.
RSpec.describe Infra::RestoreDrill do
  let(:s3) { Aws::S3::Client.new(region: "sa-east-1", stub_responses: true) }
  # The test database stands for the restored one: the checks only read it.
  let(:target_url) do
    config = ActiveRecord::Base.connection_db_config.configuration_hash
    "postgres://#{config[:username]}:#{config[:password]}@#{config[:host] || "localhost"}:#{config[:port] || 5432}/#{config[:database]}"
  end

  before do
    allow(Infra::DailyDump).to receive(:client).and_return(s3)
    s3.stub_responses(:list_objects_v2, contents: [
      { key: "daily/2026/10/21/catalysthr-20261021T060000Z.dump", size: 100, last_modified: Time.utc(2026, 10, 21, 6) },
      { key: "daily/2026/10/22/catalysthr-20261022T060000Z.dump", size: 120, last_modified: Time.utc(2026, 10, 22, 6) }
    ])
    s3.stub_responses(:get_object, body: "PGDMP")
  end

  it "restores the latest dump without the password on the command line and records the checks (CA-20-008)" do
    restore = nil
    allow(Open3).to receive(:capture3) do |env, *args|
      restore = [ env, args ]
      [ "", "", instance_double(Process::Status, success?: true, exitstatus: 0) ]
    end

    run = described_class.run(target_url: target_url)

    expect(s3.api_requests.map { |request| request[:operation_name] }).to eq(%i[list_objects_v2 get_object])
    expect(s3.api_requests.last[:params][:key]).to eq("daily/2026/10/22/catalysthr-20261022T060000Z.dump")
    env, args = restore
    expect(args.first(5)).to eq([ "pg_restore", "--no-owner", "--no-privileges", "--exit-on-error", "--dbname" ])
    expect(args.join(" ")).not_to include(":#{ActiveRecord::Base.connection_db_config.configuration_hash[:password]}@")
    expect(env).to include("PGHOST")
    expect(run).to have_attributes(kind: "restore_drill", status: "succeeded", size_bytes: 120,
      s3_key: "daily/2026/10/22/catalysthr-20261022T060000Z.dump")
    expect(run.checks["schema_version"]).to eq(ActiveRecord::Base.connection.select_value("SELECT MAX(version) FROM schema_migrations"))
    # Another connection: it does not see this test's rows, still in a transaction.
    expect(run.checks["tables"]).to include("partners", "backup_runs", "schema_migrations")
    expect(run.checks["tables"].values).to all(be_a(Integer))
  end

  it "records the failure when pg_restore fails" do
    allow(Open3).to receive(:capture3).and_return([ "", "could not connect", instance_double(Process::Status, success?: false, exitstatus: 1) ])

    expect { described_class.run(target_url: target_url) }.to raise_error(described_class::Failed, /could not connect/)
    expect(BackupRun.sole).to have_attributes(kind: "restore_drill", status: "failed")
  end

  it "fails without any dump" do
    s3.stub_responses(:list_objects_v2, contents: [])

    expect { described_class.run(target_url: target_url) }.to raise_error(described_class::Failed, "no dump under daily/")
  end
end
