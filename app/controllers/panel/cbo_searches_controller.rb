module Panel
  # Search of the official CBO for the position's form (RN-04-031): by the code's start or
  # by part of the title.
  class CboSearchesController < BaseController
    before_action :require_current_company

    def index
      authorize! :lookup, :cbo
      render json: CboOccupation.search(params[:q]).map { |occupation| { code: occupation.code, title: occupation.title } }
    end
  end
end
