module Notifications
  # A mandatory notice whose delivery failed goes to the next channel the person can get
  # (RN-15-081, CA-15-008, D-654). One fallback per failed delivery, even if this runs twice;
  # the unique index settles two runs at the same time. Optional notices have no fallback
  # (RN-15-082). A push of a fallback still waits for the quiet hours.
  class FallbackJob < ApplicationJob
    queue_as :notifications

    def perform(delivery)
      notification = delivery.notification
      return unless delivery.failed? && notification.mandatory
      return if NotificationDelivery.exists?(fallback_from: delivery)

      channel = Notifications.next_channel(user: notification.recipient_user, brand: notification.brand,
        used: notification.deliveries.pluck(:channel))
      return unless channel

      fallback = Notifications.add_delivery(notification, channel, fallback_from: delivery)
      Notifications.dispatch(fallback) if fallback.queued?
    rescue ActiveRecord::RecordNotUnique
      nil
    end
  end
end
