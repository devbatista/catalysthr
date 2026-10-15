module Brands
  # Moves a brand to a new subdomain. The old slug redirects for 90 days and is then
  # released (RN-01-022, D-157). Going back to a slug still redirecting reactivates it.
  # Only the superadmin may change a slug (spec 01, section 6).
  class ChangeSlug
    def self.call(brand:, slug:)
      new(brand: brand, slug: slug).call
    end

    def initialize(brand:, slug:)
      @brand = brand
      @slug = slug.to_s.strip.downcase
    end

    def call
      current = @brand.subdomains.active.first
      return current if current&.slug == @slug

      subdomain = BrandSubdomain.transaction do
        current&.update!(status: "redirecting", redirect_until: BrandSubdomain::REDIRECT_PERIOD.from_now)
        reactivate || @brand.subdomains.create!(slug: @slug)
      end

      # Older redirects of this brand now point to the new slug.
      @brand.subdomains.reload.each(&:expire_host_lookup)
      subdomain
    end

    private

    def reactivate
      previous = @brand.subdomains.redirecting.find_by(slug: @slug)
      previous&.tap { |subdomain| subdomain.update!(status: "active", redirect_until: nil) }
    end
  end
end
