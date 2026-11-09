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
      NotificationDigest.where(created_at: ...Notification::RETENTION.ago).in_batches(of: BATCH, &:delete_all)
      purge_announcements
    end

    private

    # The board's history keeps a notice 2 years after its validity or its withdrawal
    # (RN-15-091, D-656); its reads and its file leave with it.
    def purge_announcements
      company_ids = CrossCompany.scope(Announcement, Company.all).past_retention.distinct.pluck(:company_id)
      Company.where(id: company_ids).find_each do |company|
        ActsAsTenant.with_tenant(company) { Announcement.past_retention.find_each(&:destroy!) }
      end
    end
  end
end
