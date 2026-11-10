module Panel
  # The HR's batches (spec 08, RN-08-060 to RN-08-063, D-277, D-644): a batch is created,
  # gets files in rounds of up to 20, up to 100, and each file gets its type and person,
  # only of the scope of who sent it, and is confirmed or discarded before the confirmed
  # ones are distributed (CA-08-006). The AI suggests the type and the system the person, in
  # the same scope (RN-14-030, RN-14-031, D-672). Each person sees only their own batches.
  class DocumentBatchesController < BaseController
    include DocumentAudienceForm

    before_action :require_current_company
    before_action :load_batch, only: %i[show files items distribute]

    def index
      authorize! :read, DocumentBatch
      @batches = DocumentBatch.accessible_by(current_ability, :read).includes(:items).order(created_at: :desc).limit(50)
    end

    def create
      authorize! :create, DocumentBatch
      batch = DocumentBatch.create!(uploaded_by: current_user)
      redirect_to document_batch_path(batch)
    end

    def show
      authorize! :read, @batch
      @items = @batch.items.includes(:confirmed_type, :confirmed_worker_profile, :suggested_type, :ai_extraction,
        suggested_worker_profile: :user, file_attachment: { blob: :file_scan }).to_a
    end

    def files
      authorize! :update, @batch
      upload = Documents::BatchUpload.new(batch: @batch, files: params[:files])
      if upload.save
        redirect_to document_batch_path(@batch), notice: t(".added", count: upload.uploads.size)
      else
        redirect_to document_batch_path(@batch), alert: upload.errors.full_messages.to_sentence
      end
    end

    def items
      authorize! :update, @batch
      review = Documents::BatchReview.new(@batch, ability: current_ability, by: current_user)
      choices = params.fetch(:items, {}).each_pair.to_h do |id, choice|
        [ id, choice.permit(:document_type_id, :worker_profile_id, :status).to_h ]
      end
      if review.update(choices)
        redirect_to document_batch_path(@batch), notice: t(".saved")
      else
        redirect_to document_batch_path(@batch), alert: review_errors(review)
      end
    end

    def distribute
      authorize! :update, @batch
      review = Documents::BatchReview.new(@batch, ability: current_ability, by: current_user)
      count = review.distribute
      if count
        redirect_to document_batch_path(@batch), notice: t(".distributed", count: count)
      else
        redirect_to document_batch_path(@batch), alert: review_errors(review)
      end
    end

    private

    # Someone else's batch answers 404 (RN-03-006).
    def load_batch
      @batch = DocumentBatch.accessible_by(current_ability, :read).find(params[:id])
    end

    def review_errors(review)
      review.errors.map do |item, key|
        message = t("panel.document_batches.errors.#{key}")
        item ? "#{item.file.filename}: #{message}" : message
      end.to_sentence
    end
  end
end
