module UserSessions
  # Daily: deletes sessions closed for more than 30 days (D-576). They only serve the
  # person's list of open sessions; access events stay in access_events (spec 05).
  # Idempotent.
  class PurgeExpiredJob < ApplicationJob
    queue_as :default

    RETENTION = 30.days

    def perform
      cutoff = RETENTION.ago
      UserSession.where(expires_at: ..cutoff).or(UserSession.where(revoked_at: ..cutoff)).in_batches.delete_all
    end
  end
end
