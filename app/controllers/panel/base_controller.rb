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

    helper_method :authorized_companies, :partner_membership

    private

    # Nothing else opens until the terms and the policy in force are accepted
    # (RN-02-014, RN-02-017).
    def require_legal_acceptance
      redirect_to legal_acceptance_path if LegalAcceptance.new(current_user, Current.brand).pending?
    end

    # Companies of the brand where the person operates (RN-01-005, RN-01-011).
    def authorized_companies
      @authorized_companies ||= Company.operable_by(current_user, brand: Current.brand).order(:name)
    end

    # The membership in the partner that owns the subdomain, if any.
    def partner_membership
      return @partner_membership if defined?(@partner_membership)

      owner = Current.brand.owner
      @partner_membership = owner.is_a?(Partner) ? Membership.active.find_by(user: current_user, organization: owner) : nil
    end

    # The current company stays in the session and is the request's tenant (RN-01-005).
    # With a single company, it is chosen at once, except for the partner's team, who
    # starts at the partner's panel (RN-01-004).
    def set_current_company
      company = authorized_companies.find_by(id: session[CURRENT_COMPANY_KEY]) if session[CURRENT_COMPANY_KEY]
      company ||= authorized_companies.first if authorized_companies.one? && partner_membership.nil?
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
