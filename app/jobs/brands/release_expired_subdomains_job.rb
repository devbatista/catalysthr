module Brands
  # Releases the slugs whose 90-day redirect is over (RN-01-022). Idempotent.
  class ReleaseExpiredSubdomainsJob < ApplicationJob
    queue_as :default

    def perform
      BrandSubdomain.redirecting.where(redirect_until: ..Time.current).find_each do |subdomain|
        subdomain.update!(status: "released")
      end
    end
  end
end
