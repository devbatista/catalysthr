require "open3"
require "aws-sdk-s3"

module Infra
  # The daily pg_dump (RN-20-041, D-627), run at 3h by the Railway `backup` service with
  # `bin/rails backup:daily_dump`. The dump, in PostgreSQL's custom format, goes to the
  # `catalysthr-backups` bucket in São Paulo, encrypted by SSE-KMS with the backups key, in
  # a single PutObject: a multipart upload would need kms:Decrypt, which the backup user
  # does not have. The bucket deletes it after 35 days. Each run is recorded in backup_runs
  # and checks in to the Sentry cron monitor; a failure is reported once and raised again,
  # for the task to end the service with an error.
  module DailyDump
    MONITOR = "pg-dump-diario"
    # 3h in Brasília; Railway's cron runs it at 6h UTC.
    MONITOR_CONFIG = Sentry::Cron::MonitorConfig.from_crontab("0 3 * * *", timezone: "America/Sao_Paulo", checkin_margin: 30,
      max_runtime: 60)
    # The limit of a single PutObject.
    MAX_BYTES = 5 * 1024**3

    class Failed < StandardError; end

    module_function

    def run(now: Time.current)
      check_in = Sentry.capture_check_in(MONITOR, :in_progress, monitor_config: MONITOR_CONFIG)
      record = BackupRun.create!(kind: "daily_dump", status: "running", started_at: now)
      Dir.mktmpdir("pg_dump") do |dir|
        path = File.join(dir, "catalysthr.dump")
        dump(path)
        size = File.size(path)
        raise Failed, "dump of #{size} bytes exceeds a single upload" if size > MAX_BYTES

        key = s3_key(now)
        upload(path, key)
        record.succeed!(size_bytes: size, s3_key: key)
      end
      Sentry.capture_check_in(MONITOR, :ok, check_in_id: check_in, duration: record.duration_seconds, monitor_config: MONITOR_CONFIG)
      record
    rescue StandardError => error
      record&.fail!(error)
      Sentry.capture_check_in(MONITOR, :error, check_in_id: check_in, monitor_config: MONITOR_CONFIG)
      Rails.error.report(error, handled: false, context: { service: "backup" })
      raise
    end

    # The password goes in the environment, never on the command line.
    def dump(path)
      config = ActiveRecord::Base.connection_db_config.configuration_hash
      env = {
        "PGHOST" => config[:host].to_s, "PGPORT" => config[:port].to_s, "PGUSER" => config[:username].to_s,
        "PGPASSWORD" => config[:password].to_s, "PGDATABASE" => config[:database].to_s
      }.compact_blank
      _out, err, status = Open3.capture3(env, "pg_dump", "--format=custom", "--no-owner", "--no-privileges", "--file", path)
      raise Failed, "pg_dump exited with #{status.exitstatus}: #{err.strip.first(500)}" unless status.success?
    end

    def upload(path, key)
      File.open(path, "rb") do |file|
        client.put_object(bucket: bucket, key: key, body: file, server_side_encryption: "aws:kms", ssekms_key_id: kms_key)
      end
    end

    # daily/2026/10/22/catalysthr-20261022T060000Z.dump
    def s3_key(time)
      utc = time.utc
      "daily/#{utc.strftime("%Y/%m/%d")}/catalysthr-#{utc.strftime("%Y%m%dT%H%M%SZ")}.dump"
    end

    def client
      Aws::S3::Client.new(region: ENV.fetch("AWS_REGION", "sa-east-1"))
    end

    def bucket
      ENV.fetch("BACKUPS_BUCKET", "catalysthr-backups")
    end

    def kms_key
      ENV.fetch("BACKUPS_KMS_KEY_ID")
    end
  end
end
