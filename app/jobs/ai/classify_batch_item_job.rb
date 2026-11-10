module Ai
  # The reading of a batch's file by the AI (spec 14, RN-14-030, RN-14-031, RN-08-060, D-670,
  # D-672): the probable type, among the ones who sent the batch may choose, with the AI's
  # confidence, the fields of the profile it sees and the visual signs; then the system looks for
  # the person, by the CPF or by the name, only in that person's scope. The suggestions fill the
  # item's suggested type and person, never the HR's choice (CA-08-006). One credit per file,
  # which already pays the reading reused on distributing (RN-14-032).
  #
  # With the function off or the company paused, the file is left to the HR without a call; with
  # the queue paused by the circuit breaker, it waits (RN-14-123); after the new tries, it is marked
  # "falha da IA", without credits (RN-14-113). Idempotent: a reading no longer queued is left
  # alone, and the reading of a file discarded meanwhile is dropped without a call.
  class ClassifyBatchItemJob < ApplicationJob
    include Retries

    FEATURE = Documents::BatchReading::FEATURE

    def perform(item)
      ActsAsTenant.with_tenant(item.company) do
        extraction = AiExtraction.find_by(subject: item)
        next unless extraction&.status.in?(%w[queued retrying])
        next extraction.destroy! unless item.reload.status.in?(%w[pending confirmed]) && item.file.attached?

        case Availability.check(item.company, FEATURE)
        when :available then read(item, extraction)
        when :breaker then wait_for_breaker
        else extraction.destroy!
        end
      end
    end

    def ai_failed!(error)
      item = arguments.first
      ActsAsTenant.with_tenant(item.company) do
        AiExtraction.find_by(subject: item)&.update!(status: "failed", failed_reason: error.code)
      end
    end

    private

    def read(item, extraction)
      extraction.update!(status: "processing", attempts: extraction.attempts + 1, failed_reason: nil)
      ability = Documents::BatchReading.ability(item.batch)
      references = Prompts::BatchClassification.references(Documents::BatchReading.types(ability))

      data = call(item, references)
      fields = Extraction.normalize(data["fields"], nil)
      extraction.update!(status: "succeeded", detected_type_code: data["detected_type"], fields: fields,
        flags: Array(data["flags"]).uniq, checks: Extraction.lookups(fields),
        ai_request: AiRequest.succeeded.where(subject: item).order(:created_at).last)
      suggest(item, references[data["type_ref"]], data["type_confidence"], fields, ability)
    rescue Ai::Error
      extraction.update!(status: "retrying")
      raise
    end

    def call(item, references)
      pdf = Documents::BatchReading.pdf(item)
      Call.run(company: item.company, feature: FEATURE, subject: item, user: item.batch.uploaded_by,
        prompt_version: Prompts::BatchClassification::VERSION, attempt: ai_attempt) do |client|
        client.structured(system: Prompts::BatchClassification::SYSTEM, content: Prompts::BatchClassification.content(pdf, references),
          schema: Prompts::BatchClassification.schema, max_tokens: Prompts::BatchClassification::MAX_TOKENS,
          effort: Rails.configuration.x.ai_document_effort)
      end.data
    end

    # Only the CPF found in the scope preselects the person; the names alike are shown with the
    # score for the HR to choose (D-672).
    def suggest(item, type, type_confidence, fields, ability)
      value = ->(key) { fields.find { |field| field["key"] == key }&.dig("value") }
      person = Documents::BatchPerson.call(ability: ability, cpf: value.("cpf"), name: value.("name") || value.("holder_name"))
      item.with_lock do
        item.update!(suggested_type: type, type_confidence: type && type_confidence, suggested_worker_profile: person.profile,
          person_match: person.match, confidence: person.score, person_candidates: person.candidates)
      end
    end
  end
end
