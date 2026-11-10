require "vips"

module Documents
  # Images joined in one PDF, a page each, with Prawn (RN-08-011, CA-08-002): each image upright
  # by its EXIF, without its metadata (such as the place it was taken), on white and as a JPEG.
  # Used by a version's consolidation and by a batch's reading (RN-14-030).
  module ImagesPdf
    # A4 at 300 dpi, enough to read a document and small enough to open on a phone.
    MAX_SIDE = 3508

    module_function

    def render(blobs)
      Prawn::Document.new(page_size: "A4", margin: 24, info: { Producer: "CatalystHR" }) do |pdf|
        blobs.each_with_index do |blob, index|
          pdf.start_new_page if index.positive?
          pdf.image StringIO.new(page_image(blob.download)), fit: [ pdf.bounds.width, pdf.bounds.height ],
            position: :center, vposition: :center
        end
      end.render
    end

    def page_image(data)
      image = Vips::Image.thumbnail_buffer(data, MAX_SIDE, height: MAX_SIDE, size: :down)
      image = image.colourspace(:srgb) unless image.interpretation == :srgb
      image = image.flatten(background: [ 255, 255, 255 ]) if image.has_alpha?
      image.jpegsave_buffer(Q: 85, strip: true)
    end
  end
end
