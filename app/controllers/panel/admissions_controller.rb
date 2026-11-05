module Panel
  # The admissions (spec 07; spec 03, sections 4.4 and 4.12): the list and the page with the
  # step bar and the checklist for the HR, who creates them, changes the model and the start
  # and releases the access. The client manager reads only the step, the status, the date and
  # the items assigned to them (P-07-20, RN-03-014). The items' actions stay on the process's
  # page (spec 06). Behind the `admissions` flag (D-648).
  class AdmissionsController < BaseController
    before_action :require_current_company
    before_action :require_flag
    before_action :load_admission, only: %i[show release change_template reschedule]

    helper_method :unit_options, :department_options, :position_options, :allocation_client_options

    def index
      authorize! :read_summary, Admission
      @status = params[:status].presence_in(ProcessInstance::STATUSES) || "open"
      reachable = Admission.where(id: Admission.accessible_by(current_ability, :read_summary).select(:id))
      @counts = reachable.joins(:process_instance).group("process_instances.status").count
      @admissions = reachable.in_status(@status).includes(:process_instance, :company, process_instance: :items,
        employment: [ { worker_profile: :user }, { revisions: %i[position unit allocation_client] } ]).to_a
        .sort_by { |admission| [ admission.started_on, admission.id ] }
    end

    def show
      authorize! :read_summary, @admission
      @hr = can?(:read, @admission)
      @instance = @admission.process_instance
      @revision = @admission.employment.effective_revision
      @items = @instance.items.to_a
      @items = @items.select { |item| can?(:act, item) } unless @hr
      @people = Membership.where(id: @items.flat_map(&:responsible_membership_ids)).includes(:user).index_by(&:id)
      @templates = @hr ? ProcessTemplate.admission.active.order(:name).to_a : []
      @generated = @hr ? GeneratedDocument.where(employment_id: @admission.employment_id)
        .includes(:document_template, :signed_document, file_attachment: :blob).order(:created_at).to_a : []
      @document_templates = @hr ? DocumentTemplate.active.for_kind(@admission.employment.kind).ordered.to_a : []
      @completes_pay = @revision&.completed_by_admission? && can?(:update, @admission) && can?(:update, @admission.worker_profile)
    end

    def new
      authorize! :create, Admission
      @registration = AdmissionRegistration.new(unit_id: unit_options.first&.id)
    end

    def create
      authorize! :create, Admission
      @registration = AdmissionRegistration.new(registration_params)
      unit = Unit.find_by(id: @registration.unit_id)
      authorize! :admit_in, unit if unit
      if @registration.save(company: Current.company, by: current_user, starter: starter)
        notice = t(@registration.existing_person ? ".created_existing_person" : ".created")
        redirect_to admission_path(@registration.admission), notice: notice
      else
        render :new, status: :unprocessable_content
      end
    end

    # "Liberar acesso" (RN-07-020, D-252): the e-mail, or the link and the QR code.
    def release
      authorize! :release, @admission
      @invitation = Admissions::ReleaseAccess.call(@admission, channels: params[:channels], by: current_user)
      return render :released if @invitation

      redirect_to admission_path(@admission), notice: t(".released")
    rescue ActiveRecord::RecordInvalid => error
      redirect_to admission_path(@admission), alert: error.record.errors.full_messages.to_sentence
    end

    # Before the invitation goes out (RN-07-013, D-648).
    def change_template
      authorize! :update, @admission
      template = ProcessTemplate.admission.active.find(params[:process_template_id])
      if Admissions::ChangeTemplate.call(@admission, template: template, by: current_user, starter: starter)
        redirect_to admission_path(@admission), notice: t(".changed")
      else
        redirect_to admission_path(@admission), alert: t(".released_already")
      end
    end

    # The start moved, with the items' dates (RN-06-027, D-648).
    def reschedule
      authorize! :update, @admission
      if Admissions::Reschedule.call(@admission, started_on: params[:started_on], by: current_user)
        redirect_to admission_path(@admission), notice: t(".rescheduled")
      else
        redirect_to admission_path(@admission), alert: @admission.errors.full_messages.to_sentence
      end
    end

    private

    def require_flag
      head :not_found unless FeatureFlags.enabled?(FeatureFlags::ADMISSIONS)
    end

    # Out of the person's reach answers 404 (RN-03-006, CA-03-010).
    def load_admission
      @admission = Admission.accessible_by(current_ability, :read_summary).find(params[:id])
    end

    # The membership of who starts the process: in the company or, for the partner's
    # consultant, in the partner (RN-06-020).
    def starter
      company = Current.company
      Membership.with_access.find_by(user: current_user, organization: company) ||
        (Membership.with_access.find_by(user: current_user, organization: company.partner) if company.partner)
    end

    def registration_params
      params.expect(admission: %i[name cpf birth_date email mobile_phone social_name kind category started_on position_id unit_id
        department_id allocation_client_id])
    end

    # The HR analyst admits only in their units (U scope).
    def unit_options
      @unit_options ||= Unit.active.ordered.accessible_by(current_ability, :admit_in)
    end

    def department_options
      Department.active.includes(:unit).ordered.where(unit_id: unit_options.map(&:id))
    end

    def position_options
      Position.active.ordered
    end

    def allocation_client_options
      Current.company.uses_allocation_clients ? AllocationClient.active.ordered : AllocationClient.none
    end
  end
end
