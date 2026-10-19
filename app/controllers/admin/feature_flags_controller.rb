module Admin
  # The feature flags, for the superadmin (RN-20-030, D-617): the flags the code declares,
  # with their state and last change, turned on or off for everyone. The screen never
  # creates a flag of its own: it creates the declared ones the database lacks, and
  # removes the ones the code no longer declares.
  class FeatureFlagsController < BaseController
    def index
      authorize! :read, :feature_flags
      @last_changes = FeatureFlagChange.where(flag: FeatureFlags::ALL.map(&:to_s)).includes(:changed_by)
        .order(:created_at).index_by(&:flag)
    end

    def update
      authorize! :update, :feature_flags
      name = FeatureFlags.find(params[:name]) || raise(ActiveRecord::RecordNotFound)
      on = params[:state] == "on"
      raise ActiveRecord::RecordNotFound if !on && FeatureFlags::NOT_OFF_ON_SCREEN.include?(name)

      FeatureFlags.switch!(name, on: on, by: current_user)
      redirect_to admin_feature_flags_path, notice: t(on ? ".enabled" : ".disabled", flag: t("feature_flags.#{name}.name"))
    end

    def declare
      authorize! :update, :feature_flags
      names = FeatureFlags.declare_missing!(by: current_user)
      redirect_to admin_feature_flags_path, notice: t(".declared", count: names.size)
    end

    def destroy
      authorize! :update, :feature_flags
      name = FeatureFlags.remove_undeclared!(params[:name], by: current_user) || raise(ActiveRecord::RecordNotFound)
      redirect_to admin_feature_flags_path, notice: t(".removed", flag: name)
    end
  end
end
