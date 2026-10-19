module Panel
  module PartnerPanel
    # The partner's administrator turns the contracted modules on or off for a company of
    # the portfolio (RN-19-012, D-616). The module's price does not change with the
    # number of companies that use it (P-19-03).
    class CompanyModulesController < BaseController
      before_action :require_billing_feature
      before_action :set_company

      def edit
        authorize! :manage_modules, @company
      end

      def update
        authorize! :manage_modules, @company
        CompanyModuleSetting.apply(@company, Array(params.dig(:company, :modules)).compact_blank, by: current_user)
        redirect_to partner_root_path, notice: t(".updated", company: @company.name)
      end

      private

      # A company of the person's portfolio; any other is not found (RN-01-011, RN-01-013).
      def set_company
        @company = (partner_membership&.portfolio_companies || Company.none).find(params[:company_id])
        @contracted = partner.contracted_modules
      end
    end
  end
end
