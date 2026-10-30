module Admin
  # The holidays every company uses (RN-06-029, RN-11-020, D-242, D-336): the national
  # ones brought from BrasilAPI wait for the team's review (P-11-06, D-638), and the state
  # and city ones are registered by hand. The superadmin and the support keep them, in the
  # admin's content (RN-19-080).
  class HolidaysController < BaseController
    PERMITTED = %i[level state ibge_city_code city_name date name unit_opt_out].freeze

    before_action :load_holiday, only: %i[edit update destroy publish reject]

    def index
      authorize! :read, Holiday
      @year = year_param
      @state = params[:state].presence_in(Unit::STATES)
      holidays = Holiday.in_year(@year).ordered
      holidays = holidays.where(state: [ nil, @state ]) if @state
      @holidays = holidays.to_a.group_by(&:status)
    end

    def new
      authorize! :create, Holiday
      @holiday = Holiday.new(level: params[:level].presence_in(Holiday::LEVELS) || "city")
    end

    def create
      authorize! :create, Holiday
      @holiday = Holiday.new(holiday_params.merge(status: "published", source: "manual", reviewed_by: current_user,
        reviewed_at: Time.current))

      if @holiday.save
        redirect_to admin_holidays_path(year: @holiday.date.year), notice: t(".created")
      else
        render :new, status: :unprocessable_content
      end
    end

    def edit
      authorize! :update, @holiday
    end

    def update
      authorize! :update, @holiday
      if @holiday.update(holiday_params.except(:level))
        redirect_to admin_holidays_path(year: @holiday.date.year), notice: t(".updated")
      else
        render :edit, status: :unprocessable_content
      end
    end

    def destroy
      authorize! :destroy, @holiday
      @holiday.destroy!
      redirect_to admin_holidays_path(year: @holiday.date.year), notice: t(".destroyed")
    end

    # Only published holidays count in deadlines (P-11-06). Publishing confirms whether the
    # HR may turn it off in a unit (Good Friday, D-638).
    def publish
      authorize! :review, @holiday
      opt_out = @holiday.level_national? && ActiveModel::Type::Boolean.new.cast(params[:unit_opt_out])
      @holiday.review!("published", by: current_user, unit_opt_out: opt_out)
      redirect_to admin_holidays_path(year: @holiday.date.year), notice: t(".published", name: @holiday.name)
    end

    # A rejected holiday stays, so the next import does not propose it again.
    def reject
      authorize! :review, @holiday
      @holiday.review!("rejected", by: current_user, unit_opt_out: false)
      redirect_to admin_holidays_path(year: @holiday.date.year), notice: t(".rejected", name: @holiday.name)
    end

    # Brings a year from BrasilAPI now, for the first years or a missed run (P-11-06).
    def import
      authorize! :import, Holiday
      year = year_param
      Holidays::ImportNationalJob.perform_later(year)
      redirect_to admin_holidays_path(year: year), notice: t(".enqueued", year: year)
    end

    private

    def load_holiday
      @holiday = Holiday.find(params[:id])
    end

    def year_param
      year = params[:year].to_i
      year.between?(2000, Date.current.year + 5) ? year : Date.current.year
    end

    def holiday_params
      params.expect(holiday: PERMITTED)
    end
  end
end
