module Panel
  # The company's positions, valid in every unit (RN-04-030 to RN-04-032): the HR
  # administrator edits them and the HR analyst reads them (spec 03, section 4.2). Amounts
  # are typed in reais and kept in cents.
  class PositionsController < BaseController
    before_action :require_current_company
    before_action :load_position, only: %i[show edit update]

    def index
      authorize! :read, Position
      @positions = Position.accessible_by(current_ability).ordered
      @occupations = CboOccupation.where(code: @positions.map(&:cbo_code)).index_by(&:code)
    end

    def show
      authorize! :read, @position
    end

    def new
      authorize! :create, Position
      @position = Position.new
    end

    def create
      authorize! :create, Position
      @position = Position.new
      save(:new, t(".created"))
    end

    def edit
      authorize! :update, @position
    end

    def update
      authorize! :update, @position
      save(:edit, t(".updated"))
    end

    private

    def save(template, notice)
      attributes = params.expect(position: [ :name, :cbo_code, :salary_min, :salary_max, :description, :requirements, :status,
        :admission_template_id, { required_document_type_ids: [] } ])
      required = attributes.delete(:required_document_type_ids)
      attributes[:admission_template_id] = attributes[:admission_template_id].presence if attributes.key?(:admission_template_id)
      amounts = %i[salary_min salary_max].index_with { |field| MoneyCents.parse(attributes.delete(field)) }
      @position.assign_attributes(attributes.merge(salary_min_cents: nil, salary_max_cents: nil))
      amounts.each do |field, cents|
        cents == :invalid ? @position.errors.add(:"#{field}_cents", :invalid_amount) : @position.public_send(:"#{field}_cents=", cents)
      end

      if @position.errors.none? && @position.save
        @position.required_document_type_ids = DocumentType.usable.where(id: required).pluck(:id) if required
        redirect_to position_path(@position), notice: notice
      else
        render template, status: :unprocessable_content
      end
    end

    def load_position
      # Out of the person's scope answers 404; inside it, an action not allowed answers 403
      # (RN-03-006).
      @position = Position.accessible_by(current_ability, :read).find(params[:id])
    end
  end
end
