module Panel
  # The company's modules not built yet, listed in the menu as "Em breve" (D-597). A
  # contracted module the company does not have, or a module not released to the person
  # (CA-03-001), is not found, and time tracking during the trial says it comes with the
  # contract (CA-19-003, D-616).
  class ComingSoonController < BaseController
    before_action :require_current_company

    def show
      authorize! :read, :panel_home
      @feature = params[:feature]
      @state = ComingSoon.state(@feature, Current.company) || raise(ActiveRecord::RecordNotFound)
      raise ActiveRecord::RecordNotFound unless ComingSoon.released?(@feature, current_ability)
      render "panel/shared/coming_soon"
    end
  end
end
