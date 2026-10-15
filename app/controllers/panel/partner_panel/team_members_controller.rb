module Panel
  module PartnerPanel
    # The partner's team (spec 03, section 4.1): the administrator invites administrators
    # and consultants, releases the consultant's modules (P-03-06) and assigns the
    # companies (D-052). The last active administrator stays (D-584).
    class TeamMembersController < Panel::MembershipsController
      skip_before_action :require_current_company
      skip_before_action :set_current_company

      private

      def membership_organization
        owner = Current.brand.owner
        owner.is_a?(Partner) ? owner : raise(ActiveRecord::RecordNotFound)
      end

      def invitable_roles
        PartnerAbility::INVITABLE_ROLES
      end

      def assignable_companies
        @assignable_companies ||= membership_organization.companies.order(:name)
      end
    end
  end
end
