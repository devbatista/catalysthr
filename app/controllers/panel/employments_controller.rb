module Panel
  # The person's employments (RN-04-050 to RN-04-054):
  # - a new one for someone already registered (RN-04-051);
  # - the intern's conversion to CLT, which ends the internship the day before (CA-04-006,
  #   D-604);
  # - the fields of each kind (RN-04-053, P-04-27).
  # The kind and the registration number stay as registered: the eSocial knows the
  # employment by them (RN-04-052). New employments are registered by the HR
  # administrator, as in "Novo colaborador" (D-600), and type a salary.
  class EmploymentsController < BaseController
    before_action :require_current_company
    before_action :load_profile, only: %i[new create]
    before_action :load_employment, except: %i[new create]

    helper_method :unit_options, :department_options, :position_options

    def new
      authorize! :create, WorkerProfile
      authorize! :update, @profile
      @registration = EmploymentRegistration.new(registration_number: Current.company.suggested_registration_number,
        unit_id: Current.company.headquarters&.id)
    end

    def create
      authorize! :create, WorkerProfile
      authorize! :update, @profile
      @registration = EmploymentRegistration.new(registration_params)
      if @registration.save(profile: @profile, by: current_user)
        redirect_to employee_path(@profile), notice: t(".created")
      else
        render :new, status: :unprocessable_content
      end
    end

    def conversion
      authorize! :create, WorkerProfile
      authorize! :update, @profile
      @registration = EmploymentRegistration.conversion_of(@employment, company: Current.company)
    end

    def convert
      authorize! :create, WorkerProfile
      authorize! :update, @profile
      @registration = EmploymentRegistration.new(registration_params.merge(kind: "clt"))
      if @registration.save(profile: @profile, by: current_user, converting: @employment)
        redirect_to employee_path(@profile), notice: t(".converted")
      else
        render :conversion, status: :unprocessable_content
      end
    end

    def edit
      authorize! :update, @profile
    end

    def update
      authorize! :update, @profile
      details = params.dig(:employment, :details)&.permit(*Employment::DETAILS.fetch(@employment.kind)).to_h || {}
      @employment.assign_attributes(category: params.dig(:employment, :category), details: details)
      if @employment.save
        redirect_to employee_path(@profile), notice: t(".updated")
      else
        render :edit, status: :unprocessable_content
      end
    end

    private

    # Out of the person's scope answers 404 (RN-03-006).
    def load_profile
      @profile = WorkerProfile.accessible_by(current_ability, :read).find(params[:employee_id])
    end

    def load_employment
      @employment = Employment.find(params[:id])
      @profile = WorkerProfile.accessible_by(current_ability, :read).find(@employment.worker_profile_id)
    end

    def registration_params
      params.expect(employment_form: %i[kind category registration_number started_on position_id unit_id department_id salary
        salary_unit variable_salary_description weekly_hours justification])
    end

    def unit_options
      Unit.active.ordered
    end

    def department_options
      Department.active.includes(:unit).ordered
    end

    def position_options
      Position.active.ordered
    end
  end
end
