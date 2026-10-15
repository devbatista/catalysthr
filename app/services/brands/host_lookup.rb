module Brands
  # Identifies the brand behind a subdomain slug, cached so a request does not hit
  # the database (P-01-16). Subdomain and brand changes expire the entry.
  class HostLookup
    Result = Data.define(:status, :brand_id, :target_slug, :redirect_until) do
      def active? = status == "active"
      def redirecting? = status == "redirecting"
    end

    CACHE_TTL = 1.hour

    def self.call(slug)
      data = Rails.cache.fetch(cache_key(slug), expires_in: CACHE_TTL) { find(slug) }
      return if data.nil?

      result = Result.new(**data)
      # A redirect past its period answers 404 even before the release job runs (CA-01-007).
      return if result.redirecting? && result.redirect_until <= Time.current

      result
    end

    def self.expire(slug)
      Rails.cache.delete(cache_key(slug))
    end

    def self.cache_key(slug)
      "brands/host_lookup/v1/#{slug}"
    end

    def self.find(slug)
      subdomain = BrandSubdomain.in_use.find_by(slug: slug)
      return if subdomain.nil?
      return entry(subdomain) if subdomain.active?

      target = subdomain.brand.active_subdomain
      entry(subdomain, target_slug: target.slug) if target
    end

    def self.entry(subdomain, target_slug: nil)
      {
        status: subdomain.status,
        brand_id: subdomain.brand_id,
        target_slug: target_slug,
        redirect_until: subdomain.redirect_until
      }
    end
    private_class_method :find, :entry
  end
end
