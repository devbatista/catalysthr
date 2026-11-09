module Panel
  # The departments of each unit, in a tree, with their managers (RN-04-020 to RN-04-025):
  # the HR administrator edits them, the HR analyst reads them, and the manager reads their
  # own, with the subdepartments (spec 03, section 4.2). A department is never deleted,
  # only inactivated once empty (RN-04-025).
  class DepartmentsController < BaseController
    before_action :require_current_company
    before_action :load_department, only: %i[show edit update]

    helper_method :manager_options, :parent_options

    def index
      authorize! :read, Department
      @departments = Department.accessible_by(current_ability).includes(:unit, managers: :user).ordered
      @units = Unit.where(id: @departments.map(&:unit_id)).ordered
    end

    def show
      authorize! :read, @department
    end

    def new
      authorize! :create, Department
      @department = Department.new(unit_id: params[:unit_id], parent_id: params[:parent_id])
    end

    def create
      authorize! :create, Department
      @department = Department.new
      @department.assign_attributes(department_params)
      save(:new, t(".created"))
    end

    def edit
      authorize! :update, @department
    end

    def update
      authorize! :update, @department
      @department.assign_attributes(department_params)
      save(:edit, t(".updated"))
    end

    private

    def save(template, notice)
      Department.transaction do
        @department.save!
        Departments::AssignManagers.call(department: @department, membership_ids: params.dig(:department, :manager_ids))
      end
      redirect_to department_path(@department), notice: notice
    rescue ActiveRecord::RecordInvalid => error
      @department.errors.merge!(error.record.errors) unless error.record == @department
      render template, status: :unprocessable_content
    end

    def load_department
      # Out of the person's scope answers 404; inside it, an action not allowed answers 403
      # (RN-03-006).
      @department = Department.accessible_by(current_ability, :read).find(params[:id])
    end

    # The unit is chosen at creation only: moving a department would leave its
    # subdepartments in another unit (RN-04-020).
    def department_params
      fields = @department&.persisted? ? %i[name code parent_id status] : %i[name code unit_id parent_id]
      params.expect(department: fields)
    end

    # Active managers of the company (RN-04-021).
    def manager_options
      Membership.active.with_role("manager").where(organization: Current.company).includes(:user).sort_by { |membership| membership.user.name }
    end

    # Possible parents: active departments of active units; when editing, those of the
    # department's unit, except the department and those below it (RN-04-020).
    def parent_options(department)
      scope = Department.active.where(unit_id: Unit.active.select(:id)).includes(:unit).ordered
      return scope unless department.persisted?

      scope.where(unit_id: department.unit_id).where.not(id: Department.subtree_ids(department.id))
    end
  end
end
