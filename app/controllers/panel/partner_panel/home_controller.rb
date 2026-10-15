module Panel
  module PartnerPanel
    # The portfolio: all the partner's companies for the administrator, the assigned ones
    # for the consultant (RN-01-011, D-052). The consolidated figures come with the
    # dashboards.
    class HomeController < BaseController
      def index
        authorize! :read, :partner_panel
        @companies = partner_membership.portfolio_companies.order(:name)
      end
    end
  end
end
