# Slugs the superadmin adds to the built-in reserved list (RN-01-021, P-01-11).
class ReservedSlug < ApplicationRecord
  normalizes :slug, with: ->(slug) { slug.strip.downcase }

  validates :slug, presence: true, format: { with: BrandSubdomain::FORMAT }, uniqueness: true
end
