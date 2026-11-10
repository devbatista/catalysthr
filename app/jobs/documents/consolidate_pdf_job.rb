require "vips"

module Documents
  # Once every file of a version is clean, joins the images in one PDF, a page each, with
  # Prawn (RN-08-011, CA-08-002); a PDF is already the single file. A platform type with an
  # extraction profile is then read by the AI before the review (RN-14-020, D-670); otherwise,
  # or with the AI off or paused, the version goes straight to the review (CA-14-003). A
  # published one is approved by who published it (D-643). A file with a virus rejects the
  # version (RN-08-020). Runs once per version, whichever scan ends last.
  class ConsolidatePdfJob < ApplicationJob
    queue_as :default

    # A4 at 300 dpi, enough to read a document and small enough to open on a phone.
    MAX_SIDE = 3508

    def perform(version)
      reading = false
      version.with_lock do
        next unless version.scanning?

        scans = version.scans
        if scans.any? { |scan| scan&.infected? }
          version.update!(status: "rejected_by_scan")
        elsif scans.all? { |scan| scan&.clean? }
          attach_pdf(version)
          reading = ReadyForReview.ai_reading?(version)
          version.update!(status: reading ? "ai_processing" : "awaiting_review")
        end
      end
      # Only the run that moved the version asks for the reading, so it is never read twice.
      Ai::ExtractDocumentJob.perform_later(version) if reading
      ReadyForReview.call(version)
    end

    private

    def attach_pdf(version)
      blobs = version.files.blobs.to_a
      if blobs.one? && blobs.first.content_type == Upload::PDF
        blob = blobs.first
        version.pdf.attach(blob)
        version.update!(sha256: Digest::SHA256.hexdigest(blob.download))
      else
        data = join_images(blobs)
        blob = ActiveStorage::Blob.create_and_upload!(io: StringIO.new(data), filename: "#{version.document.document_type.name}.pdf",
          content_type: Upload::PDF, identify: false, key: Upload.storage_key(version.company))
        # Made here from clean files, so it takes their scan (D-640).
        FileScan.start!(blob, from: blobs.first.file_scan)
        version.pdf.attach(blob)
        version.update!(sha256: Digest::SHA256.hexdigest(data))
      end
    end

    # Each image upright by its EXIF, without its metadata (such as the place it was
    # taken), on white and as a JPEG.
    def join_images(blobs)
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
