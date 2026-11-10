module Documents
  # The AI's reading of a batch's files (spec 14, RN-14-030 to RN-14-032, RN-08-060, D-670,
  # D-672). A clean file is read once, with the function on and the company not paused; the
  # suggestions only fill the item's suggested type and person, never the HR's choice, so nothing
  # reaches a folder without the confirmation (RN-08-061, CA-08-006). On distributing, the reading
  # moves to the version created, without a new call nor new credits (RN-14-032).
  module BatchReading
    FEATURE = "batch_classification".freeze
    READING = %w[queued processing retrying].freeze

    module_function

    # After the file's scan: queues the reading once (the extraction's subject is unique).
    def start(item)
      return unless item.clean? && item.status.in?(%w[pending confirmed])
      return unless Ai::Availability.check(item.company, FEATURE).in?(%i[available breaker])

      extraction = AiExtraction.create_or_find_by!(subject: item) { |created| created.status = "queued" }
      Ai::ClassifyBatchItemJob.perform_later(item) if extraction.previously_new_record?
    end

    # Whether the AI is still reading it: such a file stays in the batch (D-672).
    def reading?(item) = item.ai_extraction.present? && item.ai_extraction.status.in?(READING)

    # Who sent the batch, whose scope bounds the types and the people (RN-14-031).
    def ability(batch) = CompanyAbility.new(batch.uploaded_by, batch.company)

    # The types the person who sent it may choose, as on the screen (RN-14-025).
    def types(ability)
      categories = DocumentCategory.readable(health: true, pay: ability.can?(:read_pay, WorkerProfile))
      DocumentType.usable.ordered.select { |type| categories.include?(type.category) }
    end

    # The file as one PDF, for the call (RN-14-003): a PDF as it is, an image on a page.
    def pdf(item)
      blob = item.file.blob
      blob.content_type == Upload::PDF ? blob.download : ImagesPdf.render([ blob ])
    end

    # The reading goes to the version, only with the fields of the confirmed type's profile; a
    # type without a profile, or a reading that failed, leaves the version to the normal flow
    # (RN-14-032, D-672). The item's reading is not kept: its data now lives in one place.
    def transfer(item, version)
      extraction = item.ai_extraction or return
      profile = version.document.document_type.ai_extraction_profile
      if extraction.succeeded? && profile.present?
        extraction.update!(subject: version, profile_code: profile, fields: Ai::Extraction.restrict(extraction.fields, profile))
      else
        extraction.destroy!
      end
    end

    # The readings of the files deleted with the batch (RN-08-062).
    def forget(items)
      AiExtraction.where(subject_type: "DocumentBatchItem", subject_id: items.select(:id)).delete_all
    end
  end
end
