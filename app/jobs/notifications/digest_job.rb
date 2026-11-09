module Notifications
  # Every 30 minutes: makes the digests whose hour came (spec 15, section 8). What the person
  # already opened leaves the digest, and with nothing left no e-mail goes (RN-15-041). One
  # digest per membership and brand (D-655). The lines are locked and skipped when another
  # run has them, so a repeated run makes nothing twice.
  class DigestJob < ApplicationJob
    queue_as :notifications

    def perform
      due = NotificationDelivery.held.where(channel: "email", held_until: ..Time.current).includes(:notification)
      due.group_by { |delivery| delivery.notification.values_at(:recipient_membership_id, :brand_id) }.each do |(membership_id, brand_id), group|
        build(membership_id, brand_id, group.map(&:id))
      end
    end

    private

    def build(membership_id, brand_id, ids)
      NotificationDelivery.transaction do
        held = NotificationDelivery.held.where(id: ids).lock("FOR UPDATE SKIP LOCKED").includes(notification: :recipient_user).to_a
        read, unread = held.partition { |delivery| delivery.notification.read? }
        read.each { |delivery| delivery.update!(status: "cancelled") }
        # The e-mail may have bounced since the notice was created (RN-15-083, D-609).
        sendable, blocked = unread.partition do |delivery|
          delivery.notification.recipient_user.email_deliverable?(mandatory: delivery.notification.mandatory)
        end
        blocked.each { |delivery| delivery.update!(status: "failed", failed_reason: "email_unavailable") }
        next if sendable.empty?

        digest = NotificationDigest.create!(recipient_membership_id: membership_id, brand_id: brand_id,
          notification_ids: sendable.map(&:notification_id))
        sendable.each { |delivery| delivery.update!(status: "queued", digest: digest) }
        ActiveRecord.after_all_transactions_commit { DeliverDigestJob.perform_later(digest) }
      end
    end
  end
end
