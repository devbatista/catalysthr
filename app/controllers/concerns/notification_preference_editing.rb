# "Minhas notificações" (spec 15, RN-15-021 to RN-15-023), in the panel and in the portal
# (D-654): for each of the person's memberships in this brand, the external channels of each
# notice type. Without a choice, the company's default applies, and then the catalog's. A
# mandatory type keeps at least one external channel (RN-15-022, CA-15-007).
module NotificationPreferenceEditing
  extend ActiveSupport::Concern

  Section = Data.define(:membership, :types, :preferences, :defaults)

  included do
    # Open while the contract is read only (D-624).
    writes_while_locked :update
  end

  def edit
    authorize! :update, :own_notification_preferences
    @sections = sections
  end

  def update
    authorize! :update, :own_notification_preferences
    @sections = sections
    saved = NotificationPreference.transaction do
      records = @sections.flat_map { |section| assign(section) }
      records.all?(&:valid?) ? records.each(&:save!) : raise(ActiveRecord::Rollback)
    end
    return redirect_to(preferences_path, notice: t("panel.notification_preferences.update.updated")) if saved

    render :edit, status: :unprocessable_content
  end

  private

  def sections
    Membership.for_brand(Current.brand).with_access.where(user: current_user).includes(:organization).order(:id).filter_map do |membership|
      types = NotificationType.configurable_for(membership.roles)
      next if types.empty?

      preferences = NotificationPreference.where(membership: membership).index_by(&:notification_type)
      Section.new(membership, types, preferences, company_defaults(membership))
    end
  end

  def company_defaults(membership)
    return {} unless membership.organization.is_a?(Company)

    ActsAsTenant.with_tenant(membership.organization) { CompanyNotificationSetting.all.to_h { |setting| [ setting.notification_type, setting.channels ] } }
  end

  # Only the types sent are changed.
  def assign(section)
    chosen = params.dig(:preferences, section.membership.id.to_s)
    section.types.filter_map do |type|
      next unless chosen&.key?(type.code)

      record = section.preferences[type.code] ||= NotificationPreference.new(membership: section.membership, notification_type: type.code)
      record.channels = Array(chosen[type.code])
      record
    end
  end
end
