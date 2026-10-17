module Panel
  # The company's custom fields for the person's record (RN-04-080, RN-04-081, D-213),
  # created by the HR administrator. Removing a field inactivates it and keeps the values
  # (P-04-26). Sensitive data never goes here (D-605).
  class CustomFieldsController < BaseController
    before_action :require_current_company
    before_action :load_field, only: %i[edit update]

    def index
      authorize! :read, CustomFieldDefinition
      @fields = CustomFieldDefinition.accessible_by(current_ability).order(:status, :label)
    end

    def new
      authorize! :create, CustomFieldDefinition
      @field = CustomFieldDefinition.new
    end

    def create
      authorize! :create, CustomFieldDefinition
      @field = CustomFieldDefinition.new(field_params)
      @field.save ? redirect_to(custom_fields_path, notice: t(".created")) : render(:new, status: :unprocessable_content)
    end

    def edit
      authorize! :update, @field
    end

    def update
      authorize! :update, @field
      attributes = field_params.except(:field_type)
      @field.update(attributes) ? redirect_to(custom_fields_path, notice: t(".updated")) : render(:edit, status: :unprocessable_content)
    end

    private

    def load_field
      @field = CustomFieldDefinition.accessible_by(current_ability, :read).find(params[:id])
    end

    # The options come one per line.
    def field_params
      attributes = params.expect(custom_field_definition: %i[label field_type options_text required visible_to_employee
        editable_by_employee status])
      options = attributes.delete(:options_text)
      options.nil? ? attributes : attributes.merge(options: options.to_s.lines)
    end
  end
end
