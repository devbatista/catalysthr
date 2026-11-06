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

      if Current.company
        @admissions_attention = admissions_attention
        return
      end

      if partner_membership
        redirect_to partner_root_path
      elsif firm_membership
        redirect_to firm_root_path
      elsif authorized_companies.many?
        redirect_to companies_path
      end
    end

    private

    # Until the panels of spec 17, the serious alert of the activation (RN-07-085, D-653).
    def admissions_attention
      return 0 unless FeatureFlags.enabled?(FeatureFlags::ADMISSIONS) && can?(:create, Admission)

      Admission.where(id: Admission.accessible_by(current_ability, :read_summary).select(:id)).needing_attention.count
    end

    def portal_first?
      return false if Current.company.nil? || params[:panel].present? || impersonating? || Current.support_access

      roles = Membership.with_access.find_by(user: current_user, organization: Current.company)&.roles || []
      roles.any? && (roles - PORTAL_ROLES).empty? && can?(:read, :portal)
    end
  end
end
