module Panel
  module Portal
    # "Minhas notificações" in the portal (spec 15, RN-15-021, D-654).
    class NotificationPreferencesController < BaseController
      include NotificationPreferenceEditing

      private

      def preferences_path = edit_portal_notification_preferences_path
    end
  end
end
