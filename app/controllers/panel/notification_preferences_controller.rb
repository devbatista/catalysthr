module Panel
  # "Minhas notificações" in the panel (spec 15, RN-15-021).
  class NotificationPreferencesController < BaseController
    include NotificationPreferenceEditing

    private

    def preferences_path = edit_notification_preferences_path
  end
end
