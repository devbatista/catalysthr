# The external channels chosen for a notice type (spec 15, RN-15-020 to RN-15-022). Only the
# channels of the type that exist in this phase can be chosen (D-607), and a mandatory
# type keeps at least one external channel besides the bell (RN-15-022, P-15-08,
# CA-15-007).
module NotificationChannels
  extend ActiveSupport::Concern

  included do
    normalizes :channels, with: ->(channels) { channels.compact_blank.map(&:to_s).uniq }

    validates :notification_type, inclusion: { in: ->(_) { NotificationType::CATALOG.keys } }
    validate :channels_of_the_type
  end

  def type = NotificationType.find(notification_type)

  private

  def channels_of_the_type
    return unless NotificationType::CATALOG.key?(notification_type)

    errors.add(:channels, :unavailable) if (channels - type.configurable_channels).any?
    errors.add(:channels, :mandatory_external, type: I18n.t("notification_types.#{notification_type}.name")) if type.mandatory && channels.empty?
  end
end
