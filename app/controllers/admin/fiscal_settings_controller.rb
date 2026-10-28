module Admin
  # The NFS-e's fiscal settings (spec 19, RN-19-102, D-632, D-633): what goes on every
  # note, kept here, and the Asaas account's own setup, read from Asaas and shown as it is.
  # Hidden until the notes are turned on (FeatureFlags::NFSE).
  class FiscalSettingsController < BillingController
    before_action :require_nfse_feature
    before_action :load_setting

    def show
      authorize! :read, FiscalSetting
      @asaas = asaas_account
    end

    def edit
      authorize! :update, FiscalSetting
    end

    def update
      authorize! :update, FiscalSetting
      @setting.assign_attributes(setting_params.merge(updated_by: current_user))

      if @setting.save
        redirect_to admin_fiscal_settings_path, notice: t(".updated")
      else
        render :edit, status: :unprocessable_content
      end
    end

    private

    def require_nfse_feature
      head :not_found unless FeatureFlags.enabled?(FeatureFlags::NFSE)
    end

    def load_setting
      @setting = FiscalSetting.current
    end

    def setting_params
      params.expect(fiscal_setting: [ :service_code, :service_name, :nbs_code, :operation_indicator_code, :description,
        :observations, :retain_iss, *FiscalSetting::RATES ])
    end

    # The account's setup in Asaas, read on each visit: nothing of it is kept here.
    def asaas_account
      return { status: :not_configured } unless Billing::Asaas.configured?

      { status: :ok, environment: Billing::Asaas.environment, fiscal_info: Billing::Asaas.fiscal_info }
    rescue Billing::Asaas::Error => e
      Rails.error.report(e)
      { status: :unavailable, environment: Billing::Asaas.environment }
    end
  end
end
