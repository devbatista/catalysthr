module Panel
  module PartnerPanel
    # The portfolio: all the partner's companies for the administrator, the assigned ones
    # for the consultant (RN-01-011, D-052), with the modules each one uses (RN-19-012).
    # With the panels on, the consolidated view comes on top, each block in its own request
    # (spec 17, RN-17-040, D-660).
    class HomeController < BaseController
      def index
        authorize! :read, :partner_panel
        @companies = partner_membership.portfolio_companies.includes(:module_settings).order(:name)
        @billing = FeatureFlags.enabled?(FeatureFlags::BILLING)
        @contracted = @billing ? partner.contracted_modules : []
        @overview = FeatureFlags.enabled?(FeatureFlags::DASHBOARDS) && can?(:read, :partner_overview) && @companies.any?
      end
    end
  end
end
