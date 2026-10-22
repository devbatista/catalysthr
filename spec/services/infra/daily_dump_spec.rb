require "rails_helper"

# Spec 20, block 20a (RN-20-041, CA-20-003, D-627): the daily pg_dump to the backups bucket,
# encrypted by SSE-KMS in a single PutObject, recorded and checked in to Sentry.
RSpec.describe Infra::DailyDump do
  let(:s3) { Aws::S3::Client.new(region: "sa-east-1", stub_responses: true) }
  let(:now) { Time.zone.local(2026, 10, 22, 3) }
  let(:success) { instance_double(Process::Status, success?: true, exitstatus: 0) }

  around { |example| travel_to(now) { example.run } }

  before do
    allow(described_class).to receive(:client).and_return(s3)
    allow(Sentry).to receive(:capture_check_in).and_return("check-in-1")
    stub_const("ENV", ENV.to_h.merge("BACKUPS_KMS_KEY_ID" => "0692876d-247d-49c2-8e22-d96b3caad0e0"))
  end

  def fake_pg_dump(status = success, err: "")
    allow(Open3).to receive(:capture3) do |env, *args|
      @env = env
      @args = args
      File.write(args[args.index("--file") + 1], "PGDMP" * 10)
      [ "", err, status ]
    end
  end

  it "dumps in the custom format, uploads with the backups key and records the run (CA-20-003)" do
    fake_pg_dump

    run = described_class.run

    expect(@args).to eq([ "pg_dump", "--format=custom", "--no-owner", "--no-privileges", "--file", @args.last ])
    upload = s3.api_requests.sole
    expect(upload[:operation_name]).to eq(:put_object)
    expect(upload[:params]).to include(bucket: "catalysthr-backups", key: "daily/2026/10/22/catalysthr-20261022T060000Z.dump",
      server_side_encryption: "aws:kms", ssekms_key_id: "0692876d-247d-49c2-8e22-d96b3caad0e0")
    expect(run).to have_attributes(kind: "daily_dump", status: "succeeded", size_bytes: 50,
      s3_key: "daily/2026/10/22/catalysthr-20261022T060000Z.dump", started_at: now, duration_seconds: 0)
    expect(Sentry).to have_received(:capture_check_in).with("pg-dump-diario", :in_progress, monitor_config: described_class::MONITOR_CONFIG)
    expect(Sentry).to have_received(:capture_check_in).with("pg-dump-diario", :ok, check_in_id: "check-in-1", duration: 0,
      monitor_config: described_class::MONITOR_CONFIG)
  end

  it "passes the database password in the environment, never on the command line" do
    fake_pg_dump
    allow(ActiveRecord::Base.connection_db_config).to receive(:configuration_hash)
      .and_return(host: "postgres.railway.internal", port: 5432, username: "postgres", password: "segredo-do-banco", database: "railway")

    described_class.run

    expect(@env).to eq("PGHOST" => "postgres.railway.internal", "PGPORT" => "5432", "PGUSER" => "postgres",
      "PGPASSWORD" => "segredo-do-banco", "PGDATABASE" => "railway")
    expect(@args.join(" ")).not_to include("segredo-do-banco")
  end

  it "records the failure, checks in the error and raises again when pg_dump fails" do
    fake_pg_dump(instance_double(Process::Status, success?: false, exitstatus: 1), err: "connection refused")

    expect { described_class.run }.to raise_error(described_class::Failed, /pg_dump exited with 1: connection refused/)

    expect(BackupRun.sole).to have_attributes(status: "failed", error_message: "Infra::DailyDump::Failed: pg_dump exited with 1: connection refused")
    expect(s3.api_requests).to be_empty
    expect(Sentry).to have_received(:capture_check_in).with("pg-dump-diario", :error, check_in_id: "check-in-1",
      monitor_config: described_class::MONITOR_CONFIG)
  end

  it "fails when S3 refuses the upload" do
    fake_pg_dump
    s3.stub_responses(:put_object, "AccessDenied")

    expect { described_class.run }.to raise_error(Aws::S3::Errors::AccessDenied)
    expect(BackupRun.sole).to have_attributes(status: "failed", s3_key: nil)
  end

  it "refuses a dump larger than a single upload" do
    fake_pg_dump
    stub_const("#{described_class}::MAX_BYTES", 10)

    expect { described_class.run }.to raise_error(described_class::Failed, /exceeds a single upload/)
    expect(s3.api_requests).to be_empty
  end
end
