module Panel
  # Entry page after sign-in (RN-01-004). The partner's and the accounting firm's teams
  # start at their own area; with more than one company, the person chooses one first. Who
  # is only an employee or a manager at the company starts at the portal, and "Abrir painel"
  # brings them here (spec 16, RN-16-002).
  class HomeController < BaseController
    PORTAL_ROLES = %w[employee manager].freeze

    def index
      authorize! :read, :panel_home
      return redirect_to(portal_root_path) if portal_first?
      return if Current.company

      if partner_membership
        redirect_to partner_root_path
      elsif firm_membership
        redirect_to firm_root_path
      elsif authorized_companies.many?
        redirect_to companies_path
      end
    end

    private

    def portal_first?
      return false if Current.company.nil? || params[:panel].present? || impersonating? || Current.support_access

      roles = Membership.with_access.find_by(user: current_user, organization: Current.company)&.roles || []
      roles.any? && (roles - PORTAL_ROLES).empty? && can?(:read, :portal)
    end
  end
end
