module Panel
  # Base of the pages that change part of a person's record. Out of the person's scope
  # answers 404; inside it, an action not allowed answers 403 (RN-03-006).
  class EmployeeRecordsController < BaseController
    before_action :require_current_company
    before_action :load_profile

    private

    def load_profile
      @profile = WorkerProfile.accessible_by(current_ability, :read).find(params[:employee_id])
    end

    def back_to_profile(**flash)
      redirect_to employee_path(@profile), **flash
    end
  end
end
