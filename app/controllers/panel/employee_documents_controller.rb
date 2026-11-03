module Panel
  # A person's folder (spec 08, D-642), as in the prototype: the categories the person who
  # opens it may read (P-03-17, P-03-16), the documents of each one and the HR's upload of
  # a new document (RN-08-013), for a dependent's certificate or a bank account's proof too
  # (D-604), or for a process's document item (RN-06-010). The employee's side comes with
  # the portal (spec 16).
  class EmployeeDocumentsController < BaseController
    before_action :require_current_company
    before_action :load_profile

    def index
      authorize! :read, @profile
      documents = folder.includes(:document_type, :dependent, :bank_account, versions: :uploaded_by).to_a
      @by_category = documents.group_by(&:category)
      @categories = DocumentCategory::ALL.select { |category| @by_category.key?(category) || readable_categories.include?(category) }
      @category = params[:category].presence_in(@categories) || @categories.find { |category| @by_category.key?(category) } || @categories.first
    end

    def new
      authorize! :upload, folder_document
      @upload = Documents::Upload.new(worker_profile: @profile, **links)
      @upload.document_type = type_options.find { |type| type.id == params[:document_type_id] }
    end

    def create
      @upload = Documents::Upload.new(worker_profile: @profile, by: current_user, files: params.dig(:upload, :files), **links,
        document_type: DocumentType.usable.find_by(id: params.dig(:upload, :document_type_id)))
      authorize! :upload, folder_document(@upload.document_type)
      if @upload.save
        redirect_to document_path(@upload.document), notice: t(".created")
      else
        render :new, status: :unprocessable_content
      end
    end

    private

    # Out of the person's reach answers 404 (RN-03-006).
    def load_profile
      @profile = WorkerProfile.accessible_by(current_ability, :read).includes(:user).find(params[:employee_id])
    end

    def folder
      Document.kept.accessible_by(current_ability, :read).where(worker_profile: @profile)
    end

    # A document of this folder, to check what the person may do with it; without a type
    # yet, one of a category everyone with the folder reads.
    def folder_document(type = nil)
      Document.new(worker_profile: @profile, company: Current.company, document_type: type || DocumentType.new(category: "other"))
    end
    helper_method :folder_document

    def readable_categories
      @readable_categories ||= DocumentCategory::ALL.select do |category|
        can?(:read, folder_document(DocumentType.new(category: category)))
      end
    end
    helper_method :readable_categories

    # The types the HR may send to this folder: usable ones, of the categories they read.
    def type_options
      @type_options ||= DocumentType.usable.ordered.select { |type| readable_categories.include?(type.category) }
    end
    helper_method :type_options

    # The dependent, the bank account or the process item the upload is for.
    def links
      source = params[:upload] || params
      {
        dependent: (@profile.dependents.find(source[:dependent_id]) if source[:dependent_id].present?),
        bank_account: (@profile.bank_accounts.find(source[:bank_account_id]) if source[:bank_account_id].present?),
        process_item: (ProcessItem.accessible_by(current_ability, :act).find(source[:process_item_id]) if source[:process_item_id].present?)
      }
    end
  end
end
