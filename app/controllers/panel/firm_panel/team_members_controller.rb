module Panel
  module FirmPanel
    # The firm's team (RN-02-071, D-172): the administrator invites administrators and
    # accountants, removes them and resets the accountants' MFA (RN-02-044). The last
    # active administrator stays (D-584). Correcting the contact is not the firm's
    # (spec 03, section 4.2).
    class TeamMembersController < Panel::MembershipsController
      skip_before_action :require_current_company
      skip_before_action :set_current_company

      private

      def membership_organization
        firm_membership&.organization || raise(ActiveRecord::RecordNotFound)
      end

      def membership_permission(action)
        action == :correct_contact ? nil : action
      end

      def invitable_roles
        AccountingFirmAbility::INVITABLE_ROLES
      end

      def releases_modules?
        false
      end

      # The link opens this brand's subdomain, where the invitation was made (D-586).
      def invitation_brand
        Current.brand
      end
    end
  end
end
