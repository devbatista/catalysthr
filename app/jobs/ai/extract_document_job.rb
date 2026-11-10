module Ai
  # The reading of a document version by the AI (spec 14, RN-14-020 to RN-14-024, D-670), after
  # its PDF is consolidated (RN-08-011). The fields go to the version's extraction, the version
  # to the review; nothing changes the record (RN-14-001). With the function off or the company
  # paused, the version goes to the review without a call (CA-14-003, CA-14-012); with the queue
  # paused by the circuit breaker, it waits (RN-14-123). After the new tries, it goes to the
  # review marked "falha da IA", without credits (CA-14-004). Idempotent: a version no longer in
  # the reading, or already being read, is left alone.
  class ExtractDocumentJob < ApplicationJob
    include Retries

    FEATURE = "document_extraction".freeze

    def perform(version, requested_by = nil)
      ActsAsTenant.with_tenant(version.company) do
        next unless version.reload.ai_processing?

        case Availability.check(version.company, FEATURE)
        when :available then read(version, requested_by)
        when :breaker then wait_for_breaker
        else finish(version, "awaiting_review")
        end
      end
    end

    def ai_failed!(error)
      version = arguments.first
      ActsAsTenant.with_tenant(version.company) do
        AiExtraction.find_by(subject: version)&.update!(status: "failed", failed_reason: error.code)
        finish(version, "ai_failed")
      end
    end

    private

    def read(version, requested_by)
      profile = version.document.document_type.ai_extraction_profile
      extraction = AiExtraction.find_or_initialize_by(subject: version)
      extraction.assign_attributes(profile_code: profile, status: "processing", attempts: extraction.attempts + 1, failed_reason: nil)
      extraction.save!

      data = call(version, profile, requested_by)
      fields = Extraction.normalize(data["fields"], profile)
      extraction.update!(status: "succeeded", detected_type_code: data["detected_type"], fields: fields,
        flags: Array(data["flags"]).uniq, checks: Extraction.lookups(fields),
        ai_request: AiRequest.succeeded.where(subject: version).order(:created_at).last)
      finish(version, "awaiting_review")
    rescue Ai::Error
      extraction&.update!(status: "retrying") if extraction&.persisted?
      raise
    end

    def call(version, profile, requested_by)
      pdf = version.pdf.download
      type = version.document.document_type
      Call.run(company: version.company, feature: FEATURE, subject: version, user: requested_by,
        prompt_version: Prompts::DocumentExtraction::VERSION, attempt: ai_attempt) do |client|
        client.structured(system: Prompts::DocumentExtraction::SYSTEM, content: Prompts::DocumentExtraction.content(pdf, profile, type.name),
          schema: Prompts::DocumentExtraction.schema(profile), max_tokens: Prompts::DocumentExtraction::MAX_TOKENS,
          effort: Rails.configuration.x.ai_document_effort)
      end.data
    end

    # Moves the version to the review once, under its lock.
    def finish(version, status)
      moved = version.with_lock do
        next false unless version.ai_processing?

        version.update!(status: status)
      end
      Documents::ReadyForReview.call(version) if moved
    end
  end
end
