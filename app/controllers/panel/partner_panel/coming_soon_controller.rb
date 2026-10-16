module Panel
  module PartnerPanel
    # The partner's modules not built yet, listed in the menu as "Em breve" (D-597).
    class ComingSoonController < BaseController
      def show
        authorize! :read, :partner_panel
        @feature = params[:feature]
        render "panel/shared/coming_soon"
      end
    end
  end
end
