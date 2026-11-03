# The virus scan of an Active Storage file (P-05-30, RN-20-015, D-640). A file is only
# served once clean. Infected, its content leaves the storage at once; the blob's row
# stays, so the screen can say why. Without a company: the file's owner carries it.
class FileScan < ApplicationRecord
  STATUSES = %w[scanning clean infected].freeze
  # When the hourly job sends a file still in scanning back to the queue (D-640).
  RESCAN_AFTER = 1.hour

  belongs_to :blob, class_name: "ActiveStorage::Blob"

  enum :status, STATUSES.index_by(&:itself), validate: true

  after_create_commit -> { Antivirus::ScanJob.perform_later(self) }, if: :scanning?
  # A document's version waits for its files' scans (spec 08, RN-08-020).
  after_update_commit -> { Documents::ScanFinished.call(self) }, if: -> { saved_change_to_status? && !scanning? }

  # A file just uploaded waits for its scan; a copy of a scanned file takes its result,
  # since the content is the same (D-640).
  def self.start!(blob, from: nil)
    if from&.clean?
      create!(blob: blob, status: "clean", scanned_at: from.scanned_at)
    else
      create!(blob: blob)
    end
  end

  def self.pending_rescan
    scanning.where(created_at: ...RESCAN_AFTER.ago)
      .where(attempted_at: nil).or(scanning.where(attempted_at: ...RESCAN_AFTER.ago))
  end

  def record!(result)
    if result.clean?
      update!(status: "clean", signature: nil, scanned_at: Time.current)
    else
      update!(status: "infected", signature: result.signature.truncate(255), scanned_at: Time.current)
      blob.delete
    end
  end
end
