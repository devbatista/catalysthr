module Panel
  # The company's units (RN-04-010 to RN-04-014): the HR administrator registers and
  # edits them, the HR analyst reads them (spec 03, section 4.2). A unit is never
  # deleted, only inactivated (RN-04-014); the headquarters stays active.
  class UnitsController < BaseController
    PERMITTED = %i[name code registration_type registration_number postal_code street street_number complement
      district city ibge_city_code state latitude longitude time_zone status].freeze

    before_action :require_current_company
    before_action :load_unit, only: %i[show edit update]

    def index
      authorize! :read, Unit
      @units = Unit.accessible_by(current_ability).ordered
    end

    # With the year's holidays that reach the unit and its own days (RN-06-029, D-638).
    def show
      authorize! :read, @unit
      year = params[:year].to_i
      @year = year.between?(2000, Date.current.year + 5) ? year : Date.current.year
      @holidays = Holidays::Calendar.new(@unit).entries(@year)
    end

    def new
      authorize! :create, Unit
      @unit = Unit.new(time_zone: Current.company.headquarters&.time_zone || "America/Sao_Paulo")
    end

    def create
      authorize! :create, Unit
      @unit = Unit.new(unit_params)
      if @unit.save
        redirect_to unit_path(@unit), notice: t(".created")
      else
        render :new, status: :unprocessable_content
      end
    end

    def edit
      authorize! :update, @unit
    end

    def update
      authorize! :update, @unit
      if @unit.update(unit_params)
        redirect_to unit_path(@unit), notice: t(".updated")
      else
        render :edit, status: :unprocessable_content
      end
    end

    private

    def load_unit
      # Out of the person's scope answers 404; inside it, an action not allowed answers 403
      # (RN-03-006).
      @unit = Unit.accessible_by(current_ability, :read).find(params[:id])
    end

    def unit_params
      attributes = params.expect(unit: PERMITTED)
      attributes[:registration_type] = attributes[:registration_type].presence
      attributes
    end
  end
end
