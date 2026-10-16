module Brands
  # Uploads the brand's images (RN-01-030) under the owner's prefix in the bucket:
  # companies/<company_id>/brand/... for a company's brand (RN-01-014, P-01-09) and
  # partners/<partner_id>/brand/... for a partner's. The type and the size are checked
  # before anything is uploaded, from the file's content and not from its name.
  class AttachImages
    KINDS = %i[logo_light logo_dark favicon pwa_icon_large pwa_icon_small login_image].freeze
    COMPANY_KINDS = %i[logo_light logo_dark].freeze

    def self.call(**)
      new(**).call
    end

    # files: { kind => uploaded file }; removals: kinds to remove.
    def initialize(brand:, files:, removals: [], kinds: KINDS)
      @brand = brand
      @files = files.to_h.symbolize_keys.slice(*kinds).compact_blank
      @removals = Array(removals).map(&:to_sym) & kinds
    end

    # Returns true, or false with the errors on the brand.
    def call
      types = @files.to_h { |kind, file| [ kind, check(kind, file) ] }
      return false if @brand.errors.any?

      @removals.each { |kind| @brand.public_send(kind).purge_later if @brand.public_send(kind).attached? }
      @files.each { |kind, file| @brand.public_send(kind).attach(upload(kind, file, types[kind])) }
      true
    end

    private

    # The type comes only from the file's first bytes (Marcel), never from the browser
    # nor from the name: a text file named logo.png is refused.
    def check(kind, file)
      io = file.to_io
      content_type = Marcel::MimeType.for(io)
      io.rewind
      @brand.errors.add(kind, :image_type) unless content_type.in?(Brand::IMAGE_TYPES)
      @brand.errors.add(kind, :image_size) if file.size > Brand::MAX_IMAGE_SIZE
      content_type
    end

    def upload(kind, file, content_type)
      ActiveStorage::Blob.create_and_upload!(
        io: file.to_io, filename: file.original_filename, content_type: content_type, identify: false,
        key: "#{prefix}/#{kind}/#{SecureRandom.base36(28)}"
      )
    end

    def prefix
      owner = @brand.owner
      owner.is_a?(Company) ? "companies/#{owner.id}/brand" : "partners/#{owner.id}/brand"
    end
  end
end
