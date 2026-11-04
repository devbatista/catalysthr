module Panel
  module Portal
    # The employee's and the manager's portal (spec 16, RN-16-001 to RN-16-013, D-645), at
    # /portal in the brand's subdomain: one company at a time (RN-16-040), the person's own
    # data only, and the tabs that apply to them (D-421). Ordinary pages, each with its own
    # address, without a single page app (RN-16-013).
    class BaseController < Panel::BaseController
      layout "portal_app"

      before_action :require_current_company
      before_action :require_portal

      helper_method :current_membership, :current_profile, :portal_manager?, :panel_access?

      private

      def require_portal
        authorize! :read, :portal
      end

      def current_membership
        @current_membership ||= Membership.with_access.find_by(user: current_user, organization: Current.company)
      end

      # The person's record in the company, when they are an employee there.
      def current_profile
        return @current_profile if defined?(@current_profile)

        @current_profile = current_membership&.roles&.include?("employee") ? WorkerProfile.find_by(membership: current_membership) : nil
      end

      def portal_manager?
        current_membership&.roles&.include?("manager") || false
      end

      # Who also works in the panel sees "Abrir painel" (RN-16-002, RN-16-031).
      def panel_access?
        current_membership.present? && (current_membership.roles & %w[hr_admin hr_analyst manager client_manager]).any?
      end

      def require_profile
        raise ActiveRecord::RecordNotFound unless current_profile
      end
    end
  end
end
