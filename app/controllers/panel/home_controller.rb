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
        if FeatureFlags.enabled?(FeatureFlags::DASHBOARDS)
          # Who is also HR sees the HR's panel, the widest (RN-17-014).
          if can?(:read, :hr_dashboard) then hr_dashboard
          elsif can?(:read, :manager_dashboard) then manager_dashboard
          end
        end
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

    # The HR panel (spec 17, D-657): the page only frames the blocks, which come each in its
    # own request (RN-17-090).
    def hr_dashboard
      @filter = Dashboards::Filter.new(current_ability, Current.company, unit_id: params[:unit_id], client_id: params[:client_id])
      @new_admission = FeatureFlags.enabled?(FeatureFlags::ADMISSIONS) && can?(:create, Admission)
      @usage = Dashboards::Usage.shown?(current_ability, Current.company)
      render "panel/dashboards/show"
    end

    # The manager's panel (spec 17, RN-17-020, D-659): only the team, with the same content as
    # the portal's "Minha equipe" (RN-17-021). The manager starts at the portal; "Abrir
    # painel" brings them here.
    def manager_dashboard
      membership = Membership.with_access.find_by!(user: current_user, organization: Current.company)
      @overview = TeamOverview.new(membership, unit_id: params[:unit_id])
      render "panel/dashboards/manager"
    end

    # The serious alert of the activation (RN-07-085, D-653).
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
