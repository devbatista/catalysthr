module Panel
  # The company's default channels of each notice type, for the HR administrator
  # (spec 15, RN-15-020, RN-15-022). People may change their own in "Minhas notificações".
  class CompanyNotificationSettingsController < BaseController
    before_action :require_current_company

    # The types someone in the company, or a consultant serving it, can receive.
    ROLES = Membership::ROLES.fetch("Company") + %w[consultant]

    def edit
      authorize! :update_settings, Current.company
      @settings = settings
    end

    def update
      authorize! :update_settings, Current.company
      @settings = settings
      # Only the types sent are changed.
      chosen = params.fetch(:settings, {})
      @settings.each { |setting| setting.channels = Array(chosen[setting.notification_type]) if chosen.key?(setting.notification_type) }
      if @settings.all?(&:valid?)
        CompanyNotificationSetting.transaction { @settings.each(&:save!) }
        redirect_to edit_company_notification_settings_path, notice: t(".updated")
      else
        render :edit, status: :unprocessable_content
      end
    end

    private

    def settings
      saved = CompanyNotificationSetting.all.index_by(&:notification_type)
      NotificationType.configurable_for(ROLES).map do |type|
        saved[type.code] || CompanyNotificationSetting.new(notification_type: type.code, channels: type.configurable_channels)
      end
    end
  end
end
