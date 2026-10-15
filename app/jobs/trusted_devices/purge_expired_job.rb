module TrustedDevices
  # Daily: deletes remembered devices that expired or were forgotten (spec 02,
  # section 8). Idempotent.
  class PurgeExpiredJob < ApplicationJob
    queue_as :default

    def perform
      TrustedDevice.where(expires_at: ..Time.current).or(TrustedDevice.where.not(revoked_at: nil)).in_batches.delete_all
    end
  end
end
