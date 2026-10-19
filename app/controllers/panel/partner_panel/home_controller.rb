module Panel
  module PartnerPanel
    # The portfolio: all the partner's companies for the administrator, the assigned ones
    # for the consultant (RN-01-011, D-052), with the modules each one uses (RN-19-012).
    # The consolidated figures come with the dashboards.
    class HomeController < BaseController
      def index
        authorize! :read, :partner_panel
        @companies = partner_membership.portfolio_companies.includes(:module_settings).order(:name)
        @billing = FeatureFlags.enabled?(FeatureFlags::BILLING)
        @contracted = @billing ? partner.contracted_modules : []
      end
    end
  end
end
