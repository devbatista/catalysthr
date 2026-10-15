module Panel
  module PartnerPanel
    # The HR administrators of a client company, seen from the partner's panel: the
    # partner's administrator invites a new one, changes their roles or removes them
    # (P-03-35, D-585). The modules of an HR analyst stay with the company's HR
    # (P-03-06), and the contact and the MFA with who administers the profile (RN-02-044).
    class CompanyHrAdminsController < Panel::MembershipsController
      PERMISSIONS = {
        read: :read_hr_admin, invite: :invite_hr_admin, update: :change_hr_admin, revoke: :change_hr_admin,
        cancel_invitation: :change_hr_admin, resend_invitation: :change_hr_admin
      }.freeze

      skip_before_action :require_current_company
      skip_before_action :set_current_company

      private

      # A company of the person's portfolio; any other is not found (RN-01-011, RN-01-013).
      def membership_organization
        @membership_organization ||= (partner_membership&.portfolio_companies || Company.none).find(params[:company_id])
      end

      def membership_permission(action)
        PERMISSIONS[action]
      end

      def membership_collection_subject
        Membership.new(organization: membership_organization, roles: %w[hr_admin])
      end

      def membership_scope
        super.with_role("hr_admin")
      end

      # Block rules cannot narrow a query; the scope already holds only this company's
      # HR administrators.
      def memberships_listing
        membership_scope
      end

      # A new person comes in as HR administrator; an existing one can get the
      # company's other roles.
      def invitable_roles
        action_name.in?(%w[new create]) ? %w[hr_admin] : CompanyAbility::INVITABLE_ROLES
      end

      def releases_modules?
        false
      end

      # Who stopped being an HR administrator leaves this list.
      def membership_return_url(_membership)
        url_for(action: :index)
      end
    end
  end
end
