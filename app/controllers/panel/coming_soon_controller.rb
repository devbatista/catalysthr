module Panel
  # The company's modules not built yet, listed in the menu as "Em breve" (D-597).
  class ComingSoonController < BaseController
    before_action :require_current_company

    def show
      authorize! :read, :panel_home
      @feature = params[:feature]
      render "panel/shared/coming_soon"
    end
  end
end
