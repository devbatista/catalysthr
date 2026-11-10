module Documents
  # The HR's choices on a batch (RN-08-061 to RN-08-063, D-644): each file's type and person,
  # only of the scope of who sent the batch, and whether it is confirmed, discarded or still
  # waiting. Distributing puts each confirmed and clean file in the person's folder, as a
  # document whose single version follows the normal review (RN-08-063), with the AI's reading
  # of the batch reused, without a new call (RN-14-032). A file the AI is still reading stays in
  # the batch (D-672). Nothing reaches a folder without the confirmation (CA-08-006).
  class BatchReview
    ACTIONS = %w[pending confirmed discarded].freeze

    attr_reader :errors

    def initialize(batch, ability:, by:)
      @batch = batch
      @ability = ability
      @by = by
      @errors = []
    end

    # choices: { item_id => { "document_type_id", "worker_profile_id", "status" } }
    def update(choices)
      return closed unless @batch.open?

      items = @batch.items.where.not(status: "distributed").index_by(&:id)
      ActiveRecord::Base.transaction do
        choices.to_h.each do |id, choice|
          item = items[id.to_s] or next
          apply(item, choice.to_h.stringify_keys)
        end
        raise ActiveRecord::Rollback if @errors.any?
      end
      @errors.empty?
    end

    # The confirmed and clean files go to their folders; the others stay in the batch.
    def distribute
      return closed unless @batch.open?

      count = 0
      @batch.items.confirmed.includes(:confirmed_type, :confirmed_worker_profile, :ai_extraction, file_attachment: :blob).each do |item|
        next unless item.clean?
        next if BatchReading.reading?(item)

        version = ActiveRecord::Base.transaction do
          document = Document.create!(worker_profile: item.confirmed_worker_profile, document_type: item.confirmed_type,
            source: "batch", source_ref: item)
          item.update!(status: "distributed", document: document)
          document.versions.create!(number: 1, status: "scanning", uploaded_by: @batch.uploaded_by, uploaded_at: item.created_at)
            .tap { |created| created.files.attach(item.file.blob) }
            .tap { |created| BatchReading.transfer(item, created) }
        end
        # Already clean, so no scan will wake it up (D-640).
        ConsolidatePdfJob.perform_later(version)
        count += 1
      end
      if @batch.items.where(status: %w[pending confirmed]).none?
        @batch.update!(status: "distributed")
        Batches.purge(@batch.items.discarded)
      end
      count
    end

    private

    def apply(item, choice)
      status = choice["status"].presence_in(ACTIONS) || item.status
      type = DocumentType.usable.find_by(id: choice["document_type_id"]) if choice["document_type_id"].present?
      person = WorkerProfile.find_by(id: choice["worker_profile_id"]) if choice["worker_profile_id"].present?
      item.assign_attributes(status: status, confirmed_type: type, confirmed_worker_profile: person)
      return if item.discarded? || item.pending?

      if type.nil? || person.nil?
        @errors << [ item, :choice_blank ]
      elsif !@ability.can?(:upload, Document.new(worker_profile: person, company: @batch.company, document_type: type))
        @errors << [ item, :out_of_scope ]
      elsif item.infected?
        @errors << [ item, :infected ]
      end
    ensure
      item.save! if @errors.none? { |failed, _| failed == item }
    end

    def closed
      @errors << [ nil, :batch_closed ]
      false
    end
  end
end
