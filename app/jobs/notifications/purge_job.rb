module Notifications
  # Daily: notices leave the bell after 90 days and are deleted after 1 year, with their
  # deliveries (RN-15-090, D-608). In batches, so the tables are never locked for long.
  class PurgeJob < ApplicationJob
    queue_as :default

    BATCH = 1_000

    def perform
      Notification.where(archived_at: nil, created_at: ...Notification::BELL_DAYS.days.ago).in_batches(of: BATCH) do |batch|
        batch.update_all(archived_at: Time.current)
      end
      Notification.where(created_at: ...Notification::RETENTION.ago).in_batches(of: BATCH) do |batch|
        NotificationDelivery.where(notification_id: batch.select(:id)).delete_all
        batch.delete_all
      end
    end
  end
end
