module Admin
  # A new price version of a plan (RN-19-014, D-611), starting from the latest one. It is
  # valid for new contracts from its date; existing contracts keep their version until the
  # finance team migrates them. A future version is corrected by another of the same date.
  class PlanVersionsController < BillingController
    before_action :load_plan

    def new
      authorize! :create, PlanVersion
      @version = PlanVersion.based_on(@plan, @plan.latest_version)
    end

    def create
      authorize! :create, PlanVersion
      @version = PlanVersion.new(PlanVersionParams.permit(params, @plan).merge(plan: @plan, created_by: current_user))

      if @version.save
        redirect_to admin_plan_path(@plan), notice: t(".created", version: @version.version, date: l(@version.valid_from))
      else
        render :new, status: :unprocessable_content
      end
    end

    private

    def load_plan
      @plan = Plan.includes(plan_versions: :plan_modules).find(params[:plan_id])
    end
  end
end
