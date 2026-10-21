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
    before_action :refuse_writes_while_locked

    helper_method :authorized_companies, :partner_membership, :firm_membership, :contract_lock

    # Actions that stay open while the contract is read only: they change only the person's
    # own session or notices, or pay and contract (D-624).
    class_attribute :writes_while_locked_action_names, instance_writer: false, default: [].freeze

    def self.writes_while_locked(*actions)
      self.writes_while_locked_action_names = writes_while_locked_action_names + actions.map(&:to_s)
    end

    private

    # The read only of the contract the page works on: the current company's, or the
    # partner's in its own area (RN-19-051, D-613, D-624).
    def contract_lock
      return @contract_lock if defined?(@contract_lock)

      @contract_lock = ContractLock.for(Current.company || locked_area_owner)
    end

    def locked_area_owner
      Current.brand.owner if controller_path.start_with?("panel/partner_panel") && Current.brand.owner.is_a?(Partner)
    end

    # Nothing new is created or changed: the write is refused, and the page says why.
    def refuse_writes_while_locked
      return if request.get? || request.head? || writes_while_locked_action_names.include?(action_name) || contract_lock.nil?

      respond_to do |format|
        format.html { redirect_back_or_to root_path, alert: t("contract_lock.refused") }
        format.any { head :forbidden }
      end
    end

    # Nothing else opens until the terms and the policy in force are accepted
    # (RN-02-014, RN-02-017). An impersonate does not accept them for the person, and the
    # support works under the CatalystHR contract (D-581).
    def require_legal_acceptance
      return if impersonating? || Current.support_access

      redirect_to legal_acceptance_path if LegalAcceptance.new(current_user, Current.brand).pending?
    end

    # Companies of the brand where the person operates (RN-01-005, RN-01-011).
    def authorized_companies
      @authorized_companies ||= if Current.support_access
        Company.where(id: Current.support_access.company_id)
      else
        Company.operable_by(current_user, brand: Current.brand).order(:name)
      end
    end

    # The membership in the partner that owns the subdomain, if any.
    def partner_membership
      return @partner_membership if defined?(@partner_membership)

      owner = Current.brand.owner
      @partner_membership = owner.is_a?(Partner) ? Membership.active.find_by(user: current_user, organization: owner) : nil
    end

    # The membership in an accounting firm that serves a company of this brand, if any
    # (D-586).
    def firm_membership
      return @firm_membership if defined?(@firm_membership)

      @firm_membership = Membership.active.for_brand(Current.brand)
        .where(user: current_user, organization_type: "AccountingFirm").order(:id).first
    end

    # The current company stays in the session and is the request's tenant (RN-01-005).
    # With a single company, it is chosen at once, except for the partner's and the
    # accounting firm's teams, who start at their own area (RN-01-004).
    def set_current_company
      company = authorized_companies.find_by(id: session[CURRENT_COMPANY_KEY]) if session[CURRENT_COMPANY_KEY]
      company ||= authorized_companies.first if authorized_companies.one? && partner_membership.nil? && firm_membership.nil?
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
