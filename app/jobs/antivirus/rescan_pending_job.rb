module Antivirus
  # Sends back to the queue the files still in scanning an hour after the last attempt,
  # so they are released once ClamAV is back (RN-20-015, CA-20-005, D-640).
  class RescanPendingJob < ApplicationJob
    queue_as :default

    def perform
      FileScan.pending_rescan.find_each { |scan| ScanJob.perform_later(scan) }
    end
  end
end
