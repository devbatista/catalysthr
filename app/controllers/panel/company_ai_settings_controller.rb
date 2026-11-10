module Panel
  # The company's AI functions, turned on or off by the HR administrator (spec 14, RN-14-010 to
  # RN-14-012, D-389). Off, the function leaves the screens and everything goes to the manual
  # flow; what it already produced stays. The screen also shows the day's use against the safety
  # cap and the pause, if any (RN-14-114).
  class CompanyAiSettingsController < BaseController
    before_action :require_current_company
    before_action :require_ai_feature

    def edit
      authorize! :update_settings, Current.company
      load_page
    end

    def update
      authorize! :update_settings, Current.company
      chosen = Array(params[:enabled])
      CompanyAiSetting.transaction do
        Ai::Features.built.each do |feature|
          setting = CompanyAiSetting.find_or_initialize_by(feature: feature.code)
          enabled = chosen.include?(feature.code)
          next if setting.persisted? ? setting.enabled == enabled : enabled

          setting.update!(enabled: enabled, updated_by: current_user)
        end
      end
      redirect_to edit_company_ai_settings_path, notice: t(".updated")
    end

    private

    def require_ai_feature
      head :not_found unless FeatureFlags.enabled?(FeatureFlags::AI)
    end

    def load_page
      @features = Ai::Features.built
      @settings = CompanyAiSetting.where(feature: @features.map(&:code)).index_by(&:feature)
      @cap = AiDailyCap.find_by(company: Current.company, date: Ai::DailyCap.today)
      @cap_credits = @cap&.cap_credits || Ai::DailyCap.computed(Current.company)
      @breaker_until = Ai::Breaker.open_until
    end
  end
end
