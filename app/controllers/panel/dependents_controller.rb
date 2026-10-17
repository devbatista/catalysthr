module Panel
  # The person's dependents (RN-04-043), edited by who edits the record (spec 03, section
  # 4.3). A dependent who leaves is ended, never deleted (D-604). The CPF is a document:
  # the form shows it after the password (RN-02-052).
  class DependentsController < EmployeeRecordsController
    include SensitiveAccess

    before_action :load_dependent, only: %i[edit update close]

    def new
      authorize! :update, @profile
      @dependent = @profile.dependents.new
    end

    def create
      authorize! :update, @profile
      @dependent = @profile.dependents.new(dependent_params)
      @dependent.save ? back_to_profile(notice: t(".created")) : render(:new, status: :unprocessable_content)
    end

    def edit
      authorize! :update, @profile
      reveal_all_sections(%w[documents])
    end

    def update
      authorize! :update, @profile
      reveal_all_sections(%w[documents])
      return if performed?

      @dependent.update(dependent_params) ? back_to_profile(notice: t(".updated")) : render(:edit, status: :unprocessable_content)
    end

    def close
      authorize! :update, @profile
      @dependent.end!(on: params[:ended_on].presence || Date.current)
      back_to_profile(notice: t(".closed"))
    rescue ActiveRecord::RecordInvalid, Date::Error
      back_to_profile(alert: t(".invalid_date"))
    end

    private

    def load_dependent
      @dependent = @profile.dependents.active.find(params[:id])
    end

    def dependent_params
      params.expect(dependent: %i[name cpf birth_date sex relationship_type irrf family_allowance incapable])
    end
  end
end
