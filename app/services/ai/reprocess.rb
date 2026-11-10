module Ai
  # "Processar de novo" (spec 14, RN-14-121, RN-14-113): the HR asks the AI to read again a
  # version under review, failed or not. The new reading uses credits. Only once at a time: the
  # version goes back to the reading under its lock.
  module Reprocess
    module_function

    def possible?(version)
      version.reviewable? && version.readable? && version.document.publication.nil? &&
        version.document.document_type.ai_extraction_profile.present? &&
        Availability.available?(version.company, ExtractDocumentJob::FEATURE)
    end

    def call(version, by:)
      return false unless possible?(version)

      moved = version.with_lock do
        next false unless version.reviewable?

        version.update!(status: "ai_processing")
      end
      return false unless moved

      AiExtraction.find_by(subject: version)&.update!(status: "queued")
      Documents::Followers.sync(version.document, by: by)
      ExtractDocumentJob.perform_later(version, by)
      true
    end
  end
end
