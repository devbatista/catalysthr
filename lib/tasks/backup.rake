namespace :backup do
  # The Railway `backup` service runs this every day at 6h UTC, 3h in Brasília (RN-20-041).
  desc "Dump the database to the backups bucket in São Paulo (RN-20-041, D-627)"
  task daily_dump: :environment do
    run = Infra::DailyDump.run
    puts "Backup #{run.s3_key}: #{run.size_bytes} bytes em #{run.duration_seconds} s."
  rescue StandardError => error
    abort "Backup falhou: #{error.class}"
  end

  # Every 3 months, by docs/runbooks/restauracao.md (RN-20-046).
  desc "Restore the latest dump into RESTORE_DATABASE_URL and record the checks (RN-20-046, CA-20-008)"
  task restore_drill: :environment do
    run = Infra::RestoreDrill.run
    puts "Ensaio: #{run.s3_key} restaurado em #{run.duration_seconds} s, #{run.checks["tables"].size} tabelas conferidas."
  rescue StandardError => error
    abort "Ensaio falhou: #{error.class}: #{error.message}"
  end
end
