module Documents
  # A PDF published asking for the acknowledgment of one person or a group (RN-08-050,
  # D-279, D-643): the file is stored and scanned once (P-05-30), each person gets the
  # document in the folder with it, approved by who published it once clean, and an
  # acknowledgment waiting until the date. The person's notice comes with the portal (spec
  # 16). Nothing is stored during an impersonate simulation (RN-02-085).
  class Publish
    include ActiveModel::Model

    attr_accessor :title, :document_type, :file, :audience_filter, :due_on, :message, :by, :ability
    attr_reader :publication

    validates :title, presence: true, length: { maximum: 160 }
    validates :document_type, presence: true
    validates :due_on, presence: true
    validates :message, length: { maximum: 2000 }
    validate :date_ahead
    validate :pdf_given
    validate :someone

    def audience
      @audience ||= Audience.new(audience_filter, ability: ability, document_type: document_type)
    end

    def people
      @people ||= audience.profiles
    end

    def save
      return false unless valid?

      blob = upload unless Simulation.active?
      ActiveRecord::Base.transaction do
        @publication = DocumentPublication.create!(title: title, document_type: document_type, published_by: by, due_on: due_on,
          message: message, audience_filter: audience.filter)
        people.each { |profile| publish_to(profile, blob) }
        FileScan.start!(blob) if blob
      end
      true
    rescue StandardError
      blob&.purge_later
      raise
    end

    private

    def publish_to(profile, blob)
      document = Document.create!(worker_profile: profile, document_type: document_type, source: "hr", source_ref: @publication)
      version = document.versions.create!(number: 1, status: "scanning", uploaded_by: by, uploaded_at: Time.current)
      version.files.attach(blob) if blob
      @publication.acknowledgments.create!(document: document, version: version, worker_profile: profile, due_on: due_on)
    end

    def upload
      ActiveStorage::Blob.create_and_upload!(io: file, filename: file.original_filename.to_s, content_type: Upload::PDF,
        identify: false, key: Upload.storage_key(ActsAsTenant.current_tenant))
    end

    def date_ahead
      errors.add(:due_on, :past) if due_on.present? && due_on < Time.zone.today
    end

    def pdf_given
      return errors.add(:file, :blank) if file.blank?

      errors.add(:file, :pdf_only) unless FileSignature.content_type(file) == Upload::PDF
      errors.add(:file, :too_large, count: Upload::MAX_SIZE / 1.megabyte) if file.size > Upload::MAX_SIZE
    end

    def someone
      return if document_type.nil?

      errors.add(:base, audience.empty? ? :audience_blank : :nobody) if people.empty?
    end
  end
end
