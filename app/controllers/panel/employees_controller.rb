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

    helper_method :unit_options, :department_options, :position_options, :allocation_client_options

    def index
      authorize! :read, WorkerProfile
      profiles = WorkerProfile.accessible_by(current_ability)
        .includes(:user, employments: { revisions: [ :position, :unit, :allocation_client, { department: { managers: :user } } ] })
      @units = Unit.ordered.to_a
      @rows = EmployeeRow.build(profiles)
      @unit_counts = @rows.group_by { |row| row.unit&.id }.transform_values(&:size)
      @rows = @rows.select { |row| row.unit&.id.to_s == params[:unit_id] } if params[:unit_id].present?
      # By client, when the company uses them (story 8, D-570).
      if Current.company.uses_allocation_clients
        @client_counts = @rows.group_by { |row| row.revision&.allocation_client }.transform_values(&:size)
        @rows = @rows.select { |row| row.revision&.allocation_client_id.to_s == params[:client_id] } if params[:client_id].present?
      end
    end

    def show
      authorize! :read, @profile
      reveal_sections(allowed_sections)
      @admission = Admission.for_profile(@profile).order(:created_at).last
      @awaiting_release = @admission && Admission.awaiting_release.exists?(@admission.id)
    end

    # The portal's invitation of one person, by e-mail or the link and the QR code to hand
    # out (spec 16, D-645), through the invitation of spec 02 (RN-02-012).
    def invite
      profile = WorkerProfile.accessible_by(current_ability, :read).find(params[:id])
      membership = profile.membership
      authorize! :resend_invitation, membership
      # While the admission waits, only "Liberar acesso" sends it (D-252, D-648).
      if (admission = Admission.awaiting_release.for_profile(profile).first)
        return redirect_to admission_path(admission), alert: t(".awaiting_release")
      end

      @invitation = Invitations::Resend.call(membership: membership, channels: Array(params[:channels]), invited_by: current_user)
      @profile = profile
      render :portal_invited
    rescue ActiveRecord::RecordInvalid => error
      redirect_to employee_path(profile), alert: error.record.errors.full_messages.to_sentence
    end

    # The portal's invitation of everyone still without access (spec 16, D-600, D-645): by
    # e-mail to who has a valid one and no open invitation; the others are listed, to get
    # the link or the QR code on their record.
    def invite_all
      authorize! :invite, Membership
      memberships = Membership.where(organization: Current.company, status: "invited").with_role("employee").includes(:user, :worker_profile).to_a
        .select { |membership| membership.worker_profile && can?(:resend_invitation, membership) && !membership.invitation_open? }
      # Who is being admitted waits for "Liberar acesso" (D-252, D-648).
      waiting = Admission.awaiting_release.joins(:employment).pluck("employments.worker_profile_id")
      memberships = memberships.reject { |membership| membership.worker_profile.id.in?(waiting) }
      @sent, @without_email = memberships.partition { |membership| membership.user.email_deliverable? }
      @sent.each do |membership|
        Invitations::Resend.call(membership: membership, channels: %w[email], invited_by: current_user)
      end
      render :invited
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

      @profile.assign_attributes(profile_params)
      custom = params.dig(:worker_profile, :custom_fields)
      @profile.custom_field_values = custom.permit(*CustomFieldDefinition.active.pluck(:key)).to_h if custom
      # The required custom fields are checked when the HR saves the record (D-605).
      if @profile.save(context: :record_edit)
        redirect_to employee_path(@profile), notice: t(".updated")
      else
        render :edit, status: :unprocessable_content
      end
    end

    private

    def load_profile
      # Out of the person's scope answers 404; inside it, an action not allowed answers 403
      # (RN-03-006).
      @profile = WorkerProfile.accessible_by(current_ability, :read).includes(:user, employments: { revisions: %i[position unit department allocation_client] })
        .find(params[:id])
    end

    def allowed_sections
      SECTIONS.select { |_section, action| can?(action, @profile) }.keys
    end

    def registration_params
      params.expect(employee: %i[name cpf birth_date email mobile_phone social_name kind category registration_number
        started_on position_id unit_id department_id allocation_client_id salary salary_unit variable_salary_description weekly_hours justification
        experience_first_days experience_extension_days])
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

    def allocation_client_options
      Current.company.uses_allocation_clients ? AllocationClient.active.ordered : AllocationClient.none
    end
  end
end
