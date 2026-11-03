module Panel
  # The menu's "Documentos" (D-642): the versions waiting for the HR's review in their
  # scope, with filters, and each document with its versions, the file beside the review
  # and the history of uploads and reviews (RN-08-020 to RN-08-024, RN-08-081). A
  # sensitive document asks for the password first and each opening of its file is an
  # access event (D-183, D-085); during an impersonate its file stays hidden (RN-02-086).
  class DocumentsController < BaseController
    include SensitiveAccess

    PER_PAGE = 50

    before_action :require_current_company
    before_action :load_document, only: :show

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

    def show
      authorize! :read, @document
      require_sensitive_confirmation if @document.sensitive?
      return if performed?

      @versions = @document.versions.includes(:uploaded_by, :reviewed_by, pdf_attachment: { blob: :file_scan }).to_a
      @version = @versions.find { |version| version.id == params[:version_id] } || @document.latest_version
    end

    private

    # Out of the person's reach answers 404 (RN-03-006).
    def load_document
      @document = Document.kept.accessible_by(current_ability, :read)
        .includes(:document_type, :dependent, :bank_account, worker_profile: :user).find(params[:id])
    end
  end
end
