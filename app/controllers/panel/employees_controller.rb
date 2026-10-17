module Panel
  # The company's people (spec 04, RN-04-040 to RN-04-064; spec 03, section 4.3): the list
  # in the person's scope (T for the HR administrator, U for the HR analyst, E for the
  # manager, with only the basic data), the record with its employments and revisions,
  # and the "Novo colaborador" form (D-600, D-602).
  #
  # Documents, health data and pay show only after the password (RN-02-052, D-183), each
  # value becoming an access event (RN-05-020).
  class EmployeesController < BaseController
    include SensitiveAccess

    SECTIONS = { documents: :read_personal, health: :read_health, pay: :read_pay }.freeze

    before_action :require_current_company
    before_action :load_profile, only: %i[show edit update]

    helper_method :unit_options, :department_options, :position_options

    def index
      authorize! :read, WorkerProfile
      profiles = WorkerProfile.accessible_by(current_ability)
        .includes(:user, employments: { revisions: [ :position, :unit, { department: { managers: :user } } ] })
      @units = Unit.ordered.to_a
      @rows = EmployeeRow.build(profiles)
      @unit_counts = @rows.group_by { |row| row.unit&.id }.transform_values(&:size)
      @rows = @rows.select { |row| row.unit&.id.to_s == params[:unit_id] } if params[:unit_id].present?
    end

    def show
      authorize! :read, @profile
      reveal_sections(allowed_sections)
    end

    def new
      authorize! :create, WorkerProfile
      @registration = EmployeeRegistration.new(registration_number: Current.company.suggested_registration_number,
        unit_id: Current.company.headquarters&.id)
    end

    def create
      authorize! :create, WorkerProfile
      @registration = EmployeeRegistration.new(registration_params)
      if @registration.save(company: Current.company, by: current_user)
        notice = t(@registration.existing_person ? ".created_existing_person" : ".created")
        redirect_to employee_path(@registration.profile), notice: notice
      else
        render :new, status: :unprocessable_content
      end
    end

    def edit
      authorize! :update, @profile
      reveal_all_sections(%w[documents health])
    end

    def update
      authorize! :update, @profile
      reveal_all_sections(%w[documents health])
      return if performed?

      if @profile.update(profile_params)
        redirect_to employee_path(@profile), notice: t(".updated")
      else
        render :edit, status: :unprocessable_content
      end
    end

    private

    def load_profile
      # Out of the person's scope answers 404; inside it, an action not allowed answers 403
      # (RN-03-006).
      @profile = WorkerProfile.accessible_by(current_ability, :read).includes(:user, employments: { revisions: %i[position unit department] })
        .find(params[:id])
    end

    def allowed_sections
      SECTIONS.select { |_section, action| can?(action, @profile) }.keys
    end

    def registration_params
      params.expect(employee: %i[name cpf birth_date email mobile_phone social_name kind category registration_number
        started_on position_id unit_id department_id salary salary_unit variable_salary_description weekly_hours justification])
    end

    def profile_params
      params.expect(worker_profile: [
        :social_name, :sex, :race, :marital_status, :education_level,
        :birth_city, :birth_state, :birth_country, :nationality,
        :rg_number, :rg_issuer, :rg_state, :rg_issued_on, :ctps_number, :ctps_series, :ctps_state, :pis_nis, :voter_id,
        :cnh_number, :cnh_category, :cnh_expires_on, :class_registration, :class_registration_issuer, :foreign_registration,
        :lives_abroad, :postal_code, :street, :street_number, :complement, :district, :city, :ibge_city_code, :state,
        :foreign_country, :foreign_address,
        :arrived_on, :immigration_condition, :married_to_brazilian, :brazilian_children,
        :disability_rehabilitated, :disability_notes, :personal_phone, :personal_email, { disability_types: [] }
      ])
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
