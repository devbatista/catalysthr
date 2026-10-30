module Panel
  # The unit's own days (RN-06-029, D-242): the HR administrator adds holidays and optional
  # days, and turns off in the unit a national holiday the team allows it for, as Good
  # Friday (D-638). The HR analyst sees them on the unit's page.
  class UnitHolidaysController < BaseController
    before_action :require_current_company
    before_action :load_unit

    def create
      unit_holiday = UnitHoliday.new(unit_holiday_attributes.merge(company_id: @unit.company_id, unit: @unit, created_by: current_user))
      authorize! :create, unit_holiday

      if unit_holiday.save
        redirect_to unit_path(@unit, year: unit_holiday.date.year, anchor: "holidays"), notice: t(".#{unit_holiday.kind}")
      else
        redirect_to unit_path(@unit, year: params[:year].presence, anchor: "holidays"),
          alert: unit_holiday.errors.full_messages.to_sentence
      end
    end

    def destroy
      unit_holiday = UnitHoliday.where(unit: @unit).find(params[:id])
      authorize! :destroy, unit_holiday
      unit_holiday.destroy!
      redirect_to unit_path(@unit, year: unit_holiday.date.year, anchor: "holidays"), notice: t(".#{unit_holiday.kind}")
    end

    private

    # Out of the person's scope answers 404 (RN-03-006).
    def load_unit
      @unit = Unit.accessible_by(current_ability, :read).find(params[:unit_id])
    end

    # Turning off a national holiday takes only the holiday; its date comes from it.
    def unit_holiday_attributes
      if params[:holiday_id].present?
        { kind: "opt_out", holiday: Holiday.published.level_national.find_by(id: params[:holiday_id]) }
      else
        attributes = params.expect(unit_holiday: %i[kind date name])
        attributes.merge(kind: attributes[:kind].presence_in(%w[holiday optional_day]))
      end
    end
  end
end
