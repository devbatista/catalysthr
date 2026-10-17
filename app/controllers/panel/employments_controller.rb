module Panel
  # The fields of each kind of employment (RN-04-053, P-04-27), edited by who edits the
  # person's record (spec 03, section 4.3). The kind and the registration number stay as
  # registered: the eSocial knows the employment by them (RN-04-052).
  class EmploymentsController < BaseController
    before_action :require_current_company
    before_action :load_employment

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
    def load_employment
      @employment = Employment.find(params[:id])
      @profile = WorkerProfile.accessible_by(current_ability, :read).find(@employment.worker_profile_id)
    end
  end
end
