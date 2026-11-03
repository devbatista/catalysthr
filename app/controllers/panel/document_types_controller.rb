module Panel
  # Empresa → Tipos de documento (spec 08, RN-08-002 to RN-08-004, D-270, D-642), for the
  # HR administrator: the company's own types, and the platform's ones, read only, which
  # the company turns off or whose notice it changes (P-08-04). A type is archived, never
  # deleted: documents point to it.
  class DocumentTypesController < BaseController
    PERMITTED = %i[name description category internal requires_acknowledgment expiration_rule expiration_months
      max_age_days alert_days max_files status].freeze

    before_action :require_current_company
    before_action :load_type, only: %i[edit update setting]

    def index
      authorize! :read, DocumentType
      types = DocumentType.ordered.includes(:settings, position_expirations: :position).to_a
      @own, @platform = types.partition(&:company_id)
      @positions = Position.active.ordered
    end

    def new
      authorize! :create, DocumentType
      @type = DocumentType.new(category: params[:category].presence_in(DocumentCategory::ALL) || "other")
    end

    def create
      authorize! :create, DocumentType
      @type = DocumentType.new(type_params)
      if @type.save
        redirect_to document_types_path, notice: t(".created", name: @type.name)
      else
        render :new, status: :unprocessable_content
      end
    end

    def edit
      authorize! :update, @type
    end

    def update
      authorize! :update, @type
      if @type.update(type_params)
        redirect_to document_types_path, notice: t(".updated", name: @type.name)
      else
        render :edit, status: :unprocessable_content
      end
    end

    # Turns a platform's type off or on, and changes its notice (RN-08-004, D-275).
    def setting
      authorize! :configure, @type
      setting = @type.settings.find_or_initialize_by(company: Current.company)
      setting.assign_attributes(params.expect(setting: %i[enabled alert_days]))
      if setting.save
        redirect_to document_types_path(anchor: "platform"), notice: t(".saved", name: @type.name)
      else
        redirect_to document_types_path(anchor: "platform"), alert: setting.errors.full_messages.to_sentence
      end
    end

    private

    # Out of the person's reach answers 404 (RN-03-006).
    def load_type
      @type = DocumentType.accessible_by(current_ability, :read).find(params[:id])
    end

    def type_params
      params.expect(document_type: PERMITTED)
    end
  end
end
