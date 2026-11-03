module Documents
  # An upload to a person's folder (spec 08, RN-08-010 to RN-08-014, D-642): a new document
  # of a type, or a new version of an existing one. Only PDF, JPG and PNG, checked by their
  # content, up to 10 MB each; up to the type's number of images, or a single PDF
  # (P-08-05). Each file goes to the storage under the company's prefix (P-08-07) and to the
  # virus scan (P-05-30); the version waits there. Nothing is stored during an impersonate
  # simulation, which is rolled back (RN-02-085).
  class Upload
    include ActiveModel::Model

    MAX_SIZE = 10.megabytes
    PDF = "application/pdf".freeze

    attr_accessor :worker_profile, :document, :document_type, :dependent, :bank_account, :process_item, :files, :by
    attr_reader :version

    validate :type_usable
    validate :process_item_open
    validate :files_valid

    def self.storage_key(company)
      "companies/#{company.id}/documents/#{SecureRandom.uuid}"
    end

    def save
      return false unless valid?

      blobs = Simulation.active? ? [] : upload_blobs
      ActiveRecord::Base.transaction do
        @document ||= create_document
        @document.lock!
        @version = @document.versions.create!(number: (@document.versions.maximum(:number) || 0) + 1, status: "scanning",
          uploaded_by: by, uploaded_at: Time.current)
        blobs.each do |blob|
          @version.files.attach(blob)
          FileScan.start!(blob)
        end
      end
      Processes::DocumentItem.sync(@document, by: by)
      true
    rescue StandardError
      blobs&.each(&:purge_later)
      raise
    end

    def type
      document&.document_type || document_type
    end

    private

    def create_document
      source = process_item ? "process" : "hr"
      Document.create!(worker_profile: worker_profile, document_type: document_type, dependent: dependent,
        bank_account: bank_account, source: source, source_ref: process_item)
    end

    def upload_blobs
      company = ActsAsTenant.current_tenant
      uploads.map do |file|
        ActiveStorage::Blob.create_and_upload!(io: file, filename: file.original_filename.to_s,
          content_type: FileSignature.content_type(file), identify: false, key: self.class.storage_key(company))
      end
    end

    def uploads
      Array(files).compact_blank
    end

    def type_usable
      return errors.add(:base, :read_only) if document&.read_only?
      return if document

      errors.add(:document_type, :blank) unless document_type&.enabled?
    end

    # The process item of a document of that type, still waiting for it (RN-06-010, D-642).
    def process_item_open
      return unless process_item

      waiting = process_item.document? && process_item.status.in?(%w[pending correction_requested]) &&
        process_item.instance.open? && process_item.config["document_type_id"] == type&.id
      errors.add(:base, :process_item_closed) unless waiting
    end

    def files_valid
      return errors.add(:files, :blank) if uploads.empty?

      types = uploads.map { |file| FileSignature.content_type(file) }
      return errors.add(:files, :format, formats: "PDF, JPG, PNG") if types.include?(nil)

      errors.add(:files, :too_large, count: MAX_SIZE / 1.megabyte) if uploads.any? { |file| file.size > MAX_SIZE }
      if types.include?(PDF)
        errors.add(:files, :single_pdf) if uploads.size > 1
      elsif type && uploads.size > type.max_files
        errors.add(:files, :too_many, count: type.max_files)
      end
    end
  end
end
