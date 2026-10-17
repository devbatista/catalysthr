module Panel
  # The company's settings, for the HR administrator (RN-04-002, D-601): names and rules.
  # The employer's type and document are shown read-only; only the superadmin corrects
  # them. The headquarters' address is the headquarters unit's.
  class CompanySettingsController < BaseController
    before_action :require_current_company

    def edit
      authorize! :update_settings, Current.company
      @company = Current.company
    end

    def update
      authorize! :update_settings, Current.company
      @company = Current.company
      if @company.update(params.expect(company: %i[legal_name name read_only_period_days]))
        redirect_to edit_company_settings_path, notice: t(".updated")
      else
        render :edit, status: :unprocessable_content
      end
    end
  end
end
