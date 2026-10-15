module Panel
  # Choosing and switching the current company (RN-01-004, RN-01-005). Only the
  # authorized companies are listed or accepted.
  class CompaniesController < BaseController
    def index
      authorize! :read, :panel_home
    end

    def select
      authorize! :read, :panel_home
      company = authorized_companies.find(params[:company_id])
      session[CURRENT_COMPANY_KEY] = company.id
      redirect_to root_path
    end
  end
end
