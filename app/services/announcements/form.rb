module Announcements
  # The HR's form of a notice of the board (RN-15-070, RN-15-071, D-656): the title, the text,
  # the attachment, the audience, now, later or kept as a draft, the validity and the pin. The
  # HR analyst chooses among their units (P-15-22). A published notice changes only its
  # validity and the pin (D-656). The dates are the headquarters' (the notice is the
  # company's). The file goes to the storage under the company's prefix and to the virus
  # scan; the notice goes up when it is clean (D-656). Nothing is stored during an
  # impersonate simulation (RN-02-085).
  class Form
    include ActiveModel::Model

    MODES = %w[draft now schedule].freeze

    attr_accessor :title, :body, :file, :remove_attachment, :audience, :mode, :publish_at, :expires_on, :pinned
    attr_reader :announcement

    validates :mode, inclusion: { in: MODES }, if: :content_editable?
    validate :publication_date
    validate :validity_date
    validate :audience_allowed
    validate :file_valid
    validate :record_valid

    # unit_ids: the units the person may choose, or :all (P-15-22).
    def initialize(announcement, by:, unit_ids:, **attributes)
      @announcement = announcement
      @by = by
      @unit_ids = unit_ids
      load_defaults
      super(**attributes)
    end

    def self.zone(company)
      ActiveSupport::TimeZone[ActsAsTenant.with_tenant(company) { company.headquarters }.time_zone]
    end

    def zone
      @zone ||= self.class.zone(announcement.company || ActsAsTenant.current_tenant)
    end

    def content_editable?
      announcement.content_editable?
    end

    def audience_filter
      @audience_filter ||= Audience.new(audience)
    end

    def save
      return false unless valid?

      blob = upload if content_editable? && file.present? && !Simulation.active?
      Announcement.transaction do
        assign
        announcement.attachment = blob if blob
        announcement.attachment.detach if !blob && remove_attachment? && announcement.attachment.attached?
        announcement.save!
        FileScan.start!(blob) if blob
      end
      Publish.call(announcement) if announcement.scheduled?
      true
    rescue StandardError
      blob&.purge_later
      raise
    end

    private

    def load_defaults
      record = announcement
      @title = record.title
      @body = record.body
      @audience = record.audience
      @pinned = record.pinned
      @mode = record.scheduled? ? "schedule" : "draft"
      @publish_at = record.publish_at&.in_time_zone(zone)&.strftime("%Y-%m-%dT%H:%M")
      @expires_on = (record.expires_at&.in_time_zone(zone)&.to_date || (zone.today + Announcement::DEFAULT_DAYS)).iso8601
    end

    def assign
      announcement.assign_attributes(pinned: ActiveModel::Type::Boolean.new.cast(pinned) || false, expires_at: expires_at)
      return unless content_editable?

      announcement.assign_attributes(title: title, body: body, audience: audience_filter.filter, author: announcement.author || @by,
        status: mode == "draft" ? "draft" : "scheduled", publish_at: publication_time)
    end

    def publication_time
      case mode
      when "now" then Time.current
      when "schedule" then parsed_publish_at
      end
    end

    def parsed_publish_at
      zone.parse(publish_at.to_s) if publish_at.present?
    rescue ArgumentError
      nil
    end

    def expires_at
      zone.parse(Date.iso8601(expires_on.to_s).iso8601).end_of_day
    rescue Date::Error, ArgumentError
      nil
    end

    def remove_attachment?
      ActiveModel::Type::Boolean.new.cast(remove_attachment)
    end

    def upload
      company = ActsAsTenant.current_tenant
      ActiveStorage::Blob.create_and_upload!(io: file, filename: file.original_filename.to_s, content_type: FileSignature.content_type(file),
        identify: false, key: "companies/#{company.id}/announcements/#{SecureRandom.uuid}")
    end

    def publication_date
      return unless content_editable? && mode == "schedule"

      time = parsed_publish_at
      return errors.add(:publish_at, :blank) if time.nil?

      errors.add(:publish_at, :past) if time <= Time.current
    end

    def validity_date
      errors.add(:expires_on, :blank) if expires_at.nil?
    end

    # The HR analyst publishes to their units only (RN-15-070, P-15-22).
    def audience_allowed
      return if !content_editable? || @unit_ids == :all

      chosen = audience_filter.unit_ids
      errors.add(:audience, :units_required) if chosen.empty? || (chosen - @unit_ids.map(&:to_s)).any?
    end

    def file_valid
      return unless content_editable?

      # A file with a virus is replaced or removed before going up (D-656).
      if file.blank? && !remove_attachment? && mode != "draft" && announcement.scan_status == "infected"
        errors.add(:file, :infected)
      end
      return if file.blank?

      errors.add(:file, :type) unless FileSignature.content_type(file).in?(Announcement::ATTACHMENT_TYPES)
      errors.add(:file, :too_large, count: Announcement::MAX_ATTACHMENT_SIZE / 1.megabyte) if file.size > Announcement::MAX_ATTACHMENT_SIZE
    end

    # The notice's own errors, but one message per field.
    def record_valid
      assign
      return if announcement.valid?

      announcement.errors.each do |error|
        next if errors.include?(error.attribute) || (error.attribute == :expires_at && errors.include?(:expires_on))

        errors.import(error)
      end
    end
  end
end
