module Panel
  module Portal
    # The portal opened as the installed app (spec 17, RN-17-041, D-657): only the date, for
    # the partner's adoption figures, at most once a day. Nothing about the device is kept.
    # Open while the contract is read only; an impersonate or a support entry only looks.
    class AppOpeningsController < BaseController
      writes_while_locked :create

      def create
        authorize! :read, :portal
        return head(:no_content) if impersonating? || Current.support_access

        # Only the date, without callbacks: not a change of the person's record for the trail.
        current_user.update_column(:app_opened_at, Time.current) unless current_user.app_opened_at&.today?
        head :no_content
      end
    end
  end
end
