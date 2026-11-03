module Documents
  # A round of files added to a batch (RN-08-060, D-644): up to 20 at a time and 100 in the
  # batch, each a PDF, JPG or PNG up to 10 MB, checked by its content, stored under the
  # company's prefix and scanned (P-05-30). Nothing is stored during an impersonate
  # simulation (RN-02-085).
  class BatchUpload
    include ActiveModel::Model

    attr_accessor :batch, :files

    validate :batch_open
    validate :files_valid

    def save
      return false unless valid?
      return true if Simulation.active?

      blobs = uploads.map do |file|
        ActiveStorage::Blob.create_and_upload!(io: file, filename: file.original_filename.to_s,
          content_type: FileSignature.content_type(file), identify: false, key: Upload.storage_key(batch.company))
      end
      ActiveRecord::Base.transaction do
        blobs.each do |blob|
          batch.items.create!(file: blob)
          FileScan.start!(blob)
        end
      end
      true
    rescue StandardError
      blobs&.each(&:purge_later)
      raise
    end

    def uploads
      Array(files).compact_blank
    end

    private

    def batch_open
      errors.add(:base, :batch_closed) unless batch.open?
    end

    def files_valid
      return errors.add(:files, :blank) if uploads.empty?
      return errors.add(:files, :round, count: DocumentBatch::ROUND_FILES) if uploads.size > DocumentBatch::ROUND_FILES
      return errors.add(:files, :batch_full, count: DocumentBatch::MAX_FILES, room: batch.room) if uploads.size > batch.room

      errors.add(:files, :format, formats: "PDF, JPG, PNG") if uploads.any? { |file| FileSignature.content_type(file).nil? }
      errors.add(:files, :too_large, count: Upload::MAX_SIZE / 1.megabyte) if uploads.any? { |file| file.size > Upload::MAX_SIZE }
    end
  end
end
