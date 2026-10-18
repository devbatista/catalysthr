module Panel
  # The employment's revisions with an effective date (RN-04-060 to RN-04-064, D-207): a
  # promotion, a raise, a transfer, future or retroactive (RN-04-062). A future revision
  # may be edited or deleted until its date; one in force is corrected by a new one
  # (D-603). The form shows the salary, so it needs the pay permission and the password
  # (P-03-16, RN-02-052).
  class EmploymentRevisionsController < BaseController
    include SensitiveAccess

    before_action :require_current_company
    before_action :load_employment
    before_action :load_revision, only: %i[edit update destroy]

    helper_method :unit_options, :department_options, :position_options, :allocation_client_options

    def new
      authorize! :update, @profile
      authorize! :read_pay, @profile
      reveal_all_sections(%w[pay])
      @base_revision = @employment.current_revision || @employment.effective_revision
      @revision = @employment.revisions.new(
        @base_revision&.slice(:position_id, :unit_id, :department_id, :allocation_client_id, :salary_unit, :variable_salary_description, :weekly_hours) || {}
      )
    end

    def create
      authorize! :update, @profile
      authorize! :read_pay, @profile
      reveal_all_sections(%w[pay])
      return if performed?

      @revision = @employment.revisions.new(created_by: current_user)
      save(:new, t(".created"))
    end

    def edit
      authorize! :update, @profile
      authorize! :read_pay, @profile
      return if only_future

      reveal_all_sections(%w[pay])
      @base_revision = @revision
    end

    def update
      authorize! :update, @profile
      authorize! :read_pay, @profile
      return if only_future

      reveal_all_sections(%w[pay])
      return if performed?

      save(:edit, t(".updated"))
    end

    def destroy
      authorize! :update, @profile
      authorize! :read_pay, @profile
      return if only_future

      if @revision.destroy
        redirect_to employee_path(@profile), notice: t(".destroyed")
      else
        redirect_to employee_path(@profile), alert: @revision.errors.full_messages.to_sentence
      end
    end

    private

    def save(template, notice)
      attributes = params.expect(employment_revision: %i[effective_on position_id unit_id department_id allocation_client_id salary salary_unit
        variable_salary_description weekly_hours reason justification])
      @salary_typed = attributes.delete(:salary)
      cents = MoneyCents.parse(@salary_typed)
      @revision.assign_attributes(attributes.merge(salary_cents: cents == :invalid ? nil : cents))
      @revision.errors.add(:salary_cents, :invalid_amount) if cents == :invalid

      if cents != :invalid && @revision.save
        notice = t(".retroactive", notice: notice) if @revision.retroactive?
        redirect_to employee_path(@profile), notice: notice
      else
        render template, status: :unprocessable_content
      end
    end

    # Out of the person's scope answers 404 (RN-03-006).
    def load_employment
      @employment = Employment.find(params[:employment_id])
      @profile = WorkerProfile.accessible_by(current_ability, :read).find(@employment.worker_profile_id)
    end

    def load_revision
      @revision = @employment.revisions.find(params[:id])
    end

    # A revision in force is corrected by a new one (D-603). True when it redirected.
    def only_future
      return false if @revision.future?

      redirect_to employee_path(@profile), alert: t("panel.employment_revisions.in_force")
      true
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
