module Admin
  # Plans for partners and for direct companies, by the superadmin and the finance team
  # (spec 03, section 4.1, RN-19-010). A plan is created with its first price version;
  # later prices are new versions (D-611), so editing a plan changes only its name and
  # status. The add-ons and their prices are listed on the same screen (RN-19-013).
  class PlansController < BillingController
    before_action :load_plan, only: %i[show edit update]

    def index
      authorize! :read, Plan
      @plans = Plan.includes(plan_versions: :plan_modules).ordered
      @add_ons = AddOn.includes(:prices).index_by(&:code)
    end

    def new
      @plan = Plan.new(kind: known_kind(params[:kind]))
      authorize! :create, @plan
      @version = PlanVersion.based_on(@plan, nil)
    end

    def create
      attributes = params.expect(plan: %i[kind name])
      @plan = Plan.new(attributes.merge(kind: known_kind(attributes[:kind])))
      authorize! :create, @plan
      @version = PlanVersion.new(version_params.merge(plan: @plan, created_by: current_user))

      if save_with_version
        redirect_to admin_plan_path(@plan), notice: t(".created")
      else
        render :new, status: :unprocessable_content
      end
    end

    def show
      authorize! :read, @plan
    end

    def edit
      authorize! :update, @plan
    end

    def update
      authorize! :update, @plan
      if @plan.update(params.expect(plan: %i[name status]))
        redirect_to admin_plan_path(@plan), notice: t(".updated")
      else
        render :edit, status: :unprocessable_content
      end
    end

    private

    def known_kind(kind)
      kind.in?(Plan::KINDS) ? kind : raise(ActiveRecord::RecordNotFound)
    end

    def load_plan
      @plan = Plan.includes(plan_versions: %i[plan_modules created_by]).find(params[:id])
    end

    def version_params
      PlanVersionParams.permit(params, @plan)
    end

    # The plan and its first version are saved together, or neither is.
    def save_with_version
      plan_valid = @plan.valid?
      return false unless @version.valid? && plan_valid

      Plan.transaction do
        @plan.save!
        @version.save!
      end
      true
    end
  end
end
