# Pages of a brand's subdomain: the HR panel and the employee portal share the same
# address (D-155). HostResolver has already identified the brand, and
# ApplicationController has loaded it into Current.brand.
module Panel
  class BaseController < ApplicationController
    CURRENT_COMPANY_KEY = "current_company_id"

    layout "panel_app"

    set_current_tenant_through_filter

    before_action :authenticate_user!
    before_action :require_legal_acceptance
    before_action :require_mfa_setup
    before_action :set_current_company

    helper_method :authorized_companies

    private

    # Nothing else opens until the terms and the policy in force are accepted
    # (RN-02-014, RN-02-017).
    def require_legal_acceptance
      redirect_to legal_acceptance_path if LegalAcceptance.new(current_user, Current.brand).pending?
    end

    # Companies of the brand where the person has access (RN-01-002, RN-01-005). The
    # consultant's assigned companies come with the partner's panel.
    def authorized_companies
      @authorized_companies ||= Company.where(
        id: Membership.with_access.for_brand(Current.brand).where(user: current_user, organization_type: "Company")
          .select(:organization_id)
      ).order(:name)
    end

    # The current company stays in the session and is the request's tenant (RN-01-005).
    # With a single company, it is chosen at once (RN-01-004).
    def set_current_company
      company = authorized_companies.find_by(id: session[CURRENT_COMPANY_KEY]) if session[CURRENT_COMPANY_KEY]
      company ||= authorized_companies.first if authorized_companies.one?
      return session.delete(CURRENT_COMPANY_KEY) if company.nil?

      session[CURRENT_COMPANY_KEY] = company.id
      Current.company = company
      set_current_tenant(company)
    end

    def require_current_company
      redirect_to companies_path if Current.company.nil?
    end
  end
end
