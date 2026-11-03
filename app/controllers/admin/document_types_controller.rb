module Admin
  # The platform's document types (spec 08, RN-08-001, D-270, D-642), kept by the superadmin
  # and the support in the admin's content (RN-19-080). The extraction by the AI comes with
  # spec 14. A type is archived, never deleted: documents point to it.
  class DocumentTypesController < BaseController
    PERMITTED = %i[code name description category internal requires_acknowledgment expiration_rule expiration_months
      max_age_days alert_days max_files status].freeze

    before_action :load_type, only: %i[edit update]

    def index
      authorize! :read, PlatformDocumentType
      @types = PlatformDocumentType.ordered.group_by(&:category)
    end

    def new
      authorize! :create, PlatformDocumentType
      @type = PlatformDocumentType.new(category: params[:category].presence_in(DocumentCategory::ALL) || "personal")
    end

    def create
      authorize! :create, PlatformDocumentType
      @type = PlatformDocumentType.new(type_params)
      if @type.save
        redirect_to admin_document_types_path, notice: t(".created", name: @type.name)
      else
        render :new, status: :unprocessable_content
      end
    end

    def edit
      authorize! :update, @type
    end

    def update
      authorize! :update, @type
      if @type.update(type_params.except(:code))
        redirect_to admin_document_types_path, notice: t(".updated", name: @type.name)
      else
        render :edit, status: :unprocessable_content
      end
    end

    private

    def load_type
      @type = PlatformDocumentType.find(params[:id])
    end

    def type_params
      params.expect(document_type: PERMITTED)
    end
  end
end
