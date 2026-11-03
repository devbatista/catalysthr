module Panel
  # The menu's "Documentos" (D-642): the versions waiting for the HR's review in their
  # scope, with filters, and each document with its versions, the file beside the review
  # and the history of uploads and reviews (RN-08-020 to RN-08-024, RN-08-081). A
  # sensitive document asks for the password first and each opening of its file is an
  # access event (D-183, D-085); during an impersonate its file stays hidden (RN-02-086).
  # The HR administrator deletes a document with a reason and recovers it within 30 days
  # (RN-08-083, D-644).
  class DocumentsController < BaseController
    include SensitiveAccess

    PER_PAGE = 50

    before_action :require_current_company
    before_action :load_document, only: %i[show destroy]

    def index
      authorize! :review, Document
      versions = DocumentVersion.where(status: DocumentVersion::REVIEWABLE)
        .joins(:document).merge(Document.kept.accessible_by(current_ability, :review))
        .includes(:uploaded_by, document: [ :document_type, :dependent, :bank_account, { worker_profile: :user } ])
      @units = Unit.ordered.to_a
      @types = DocumentType.where(id: versions.select("documents.document_type_id")).ordered.to_a
      versions = versions.where(documents: { worker_profile_id: WorkerProfile.in_units(params[:unit_id]).select(:id) }) if params[:unit_id].present?
      versions = versions.where(documents: { document_type_id: params[:document_type_id] }) if params[:document_type_id].present?
      if params[:q].present?
        people = WorkerProfile.joins(:user).where("users.name ILIKE ?", "%#{WorkerProfile.sanitize_sql_like(params[:q].strip)}%")
        versions = versions.where(documents: { worker_profile_id: people.select(:id) })
      end
      @count = versions.count
      @versions = versions.order(:uploaded_at).limit(PER_PAGE)
    end

    # The documents expiring and expired in the HR's scope, the nearest first (RN-08-031,
    # RN-08-032). Nothing is blocked (P-08-12).
    def expirations
      authorize! :review, Document
      documents = Document.kept.accessible_by(current_ability, :read).where(status: %w[expiring expired])
        .includes(:document_type, :dependent, :bank_account, worker_profile: :user)
      @units = Unit.ordered.to_a
      documents = documents.where(worker_profile_id: WorkerProfile.in_units(params[:unit_id]).select(:id)) if params[:unit_id].present?
      documents = documents.where(status: params[:status]) if params[:status].in?(%w[expiring expired])
      @count = documents.count
      @documents = documents.order(:expires_on).limit(PER_PAGE)
    end

    def show
      authorize! :read, @document
      require_sensitive_confirmation if @document.sensitive?
      return if performed?

      @versions = @document.versions.includes(:uploaded_by, :reviewed_by, pdf_attachment: { blob: :file_scan }).to_a
      @version = @versions.find { |version| version.id == params[:version_id] } || @document.latest_version
    end

    def destroy
      authorize! :destroy, @document
      if Documents::Removal.new(@document, by: current_user).delete(reason: params[:delete_reason])
        redirect_to employee_documents_path(@document.worker_profile, category: @document.category), notice: t(".deleted")
      else
        redirect_to document_path(@document), alert: @document.errors.full_messages.to_sentence
      end
    end

    def restore
      document = Document.where.not(deleted_at: nil).accessible_by(current_ability, :read).find(params[:id])
      authorize! :restore, document
      if Documents::Removal.new(document, by: current_user).restore
        redirect_to document_path(document), notice: t(".restored")
      else
        redirect_to employee_documents_path(document.worker_profile, deleted: 1), alert: document.errors.full_messages.to_sentence
      end
    end

    private

    # Out of the person's reach answers 404 (RN-03-006).
    def load_document
      @document = Document.kept.accessible_by(current_ability, :read)
        .includes(:document_type, :dependent, :bank_account, worker_profile: :user).find(params[:id])
    end
  end
end
