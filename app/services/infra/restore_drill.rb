require "open3"

module Infra
  # The restore drill, every 3 months (RN-20-046, CA-20-008, D-627), by the steps in
  # docs/runbooks/restauracao.md: `bin/rails backup:restore_drill` restores the latest daily
  # dump into a temporary database (RESTORE_DATABASE_URL), with the restore user's
  # credentials, the only ones that read the backups. It checks the rows of every table and
  # the schema version, and records the time, the size and the checks in backup_runs. The
  # last NSR of each employer joins the checks with the time entries (spec 10).
  module RestoreDrill
    PREFIX = "daily/"

    class Failed < StandardError; end

    module_function

    def run(target_url: ENV.fetch("RESTORE_DATABASE_URL"), now: Time.current)
      record = BackupRun.create!(kind: "restore_drill", status: "running", started_at: now)
      object = latest_dump
      Dir.mktmpdir("pg_restore") do |dir|
        path = File.join(dir, "catalysthr.dump")
        client.get_object(bucket: DailyDump.bucket, key: object.key, response_target: path)
        restore(path, target_url)
        record.succeed!(size_bytes: object.size, s3_key: object.key, checks: checks(target_url))
      end
      record
    rescue StandardError => error
      record&.fail!(error)
      raise
    end

    def latest_dump
      objects = client.list_objects_v2(bucket: DailyDump.bucket, prefix: PREFIX).flat_map(&:contents)
      objects.max_by(&:last_modified) || raise(Failed, "no dump under #{PREFIX}")
    end

    # The password goes in the environment, never on the command line.
    def restore(path, target_url)
      _out, err, status = Open3.capture3(libpq_env(target_url), "pg_restore", "--no-owner", "--no-privileges", "--exit-on-error",
        "--dbname", URI(target_url).path.delete_prefix("/"), path)
      raise Failed, "pg_restore exited with #{status.exitstatus}: #{err.strip.first(500)}" unless status.success?
    end

    def checks(target_url)
      connection = PG.connect(target_url)
      tables = connection.exec("SELECT tablename FROM pg_tables WHERE schemaname = 'public' ORDER BY tablename").column_values(0)
      counts = tables.to_h { |table| [ table, connection.exec("SELECT COUNT(*) FROM #{connection.quote_ident(table)}").getvalue(0, 0).to_i ] }
      { "schema_version" => connection.exec("SELECT MAX(version) FROM schema_migrations").getvalue(0, 0), "tables" => counts }
    ensure
      connection&.close
    end

    def libpq_env(url)
      uri = URI(url)
      { "PGHOST" => uri.host, "PGPORT" => uri.port&.to_s, "PGUSER" => CGI.unescape(uri.user.to_s),
        "PGPASSWORD" => CGI.unescape(uri.password.to_s) }.compact_blank
    end

    def client
      DailyDump.client
    end
  end
end
