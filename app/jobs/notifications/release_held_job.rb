module Notifications
  # Every 5 minutes: the push held by the quiet hours whose time came (spec 15, section 8).
  # What the person already opened in the system is cancelled (RN-15-035, CA-15-004), and
  # what is left of the same type goes as one message (RN-15-034). The lines are locked and
  # skipped when another run has them, so a repeated run sends nothing twice.
  class ReleaseHeldJob < ApplicationJob
    queue_as :notifications

    def perform
      due = NotificationDelivery.held.where(held_until: ..Time.current).includes(:notification)
      due.group_by { |delivery| group_of(delivery) }.each_value { |group| release(group.map(&:id)) }
    end

    private

    def group_of(delivery)
      notification = delivery.notification
      [ delivery.channel, notification.recipient_user_id, notification.brand_id, notification.notification_type ]
    end

    def release(ids)
      NotificationDelivery.transaction do
        held = NotificationDelivery.held.where(id: ids).lock("FOR UPDATE SKIP LOCKED").includes(:notification).order(:id).to_a
        read, unread = held.partition { |delivery| delivery.notification.read? }
        read.each { |delivery| delivery.update!(status: "cancelled") }
        leader, *others = unread
        next unless leader

        others.each { |delivery| delivery.update!(status: "queued", grouped_into: leader) }
        leader.update!(status: "queued")
        Notifications.dispatch(leader)
      end
    end
  end
end
