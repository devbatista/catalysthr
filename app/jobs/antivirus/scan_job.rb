module Antivirus
  # Scans an uploaded file in ClamAV before it is released (P-05-30, RN-20-015, D-640).
  # With ClamAV out of reach, it tries again 1, 5, 15 and 30 minutes later; after that,
  # the file stays in scanning, the error goes to Sentry and RescanPendingJob sends it
  # back every hour (CA-20-005). Runs once per file: a file already scanned is left alone.
  class ScanJob < ApplicationJob
    queue_as :default

    WAITS = [ 1.minute, 5.minutes, 15.minutes, 30.minutes ].freeze

    retry_on(Clamd::Unavailable, attempts: WAITS.size + 1, wait: ->(executions) { WAITS.fetch(executions - 1, WAITS.last) }) do |_job, error|
      Sentry.capture_exception(error)
    end

    def perform(scan)
      return unless scan.scanning?

      scan.update!(attempted_at: Time.current)
      result = scan.blob.open { |file| Clamd.new.scan(file) }
      scan.record!(result)
      # Only the signature's name, never the file's (D-640).
      Sentry.capture_message("Virus found in an upload", level: :warning, extra: { signature: result.signature }) unless result.clean?
    end
  end
end
