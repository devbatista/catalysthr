# <slug>.painel.catalysthr.com.br, owned by a partner's or a direct company's brand
# (D-153, D-154, P-01-15). States: active -> redirecting (90 days) -> released.
class BrandSubdomain < ApplicationRecord
  REDIRECT_PERIOD = 90.days
  # Built-in reserved slugs (RN-01-021); the superadmin adds more in ReservedSlug.
  RESERVED = %w[
    admin www api app painel portal suporte status mail email static assets cdn totem health
  ].freeze
  # 3 to 40 characters: lowercase letters without accents, digits and hyphens,
  # not starting or ending with a hyphen (RN-01-020).
  FORMAT = /\A[a-z0-9][a-z0-9-]{1,38}[a-z0-9]\z/

  belongs_to :brand

  enum :status, { active: "active", redirecting: "redirecting", released: "released" }, validate: true

  scope :in_use, -> { where.not(status: "released") }

  normalizes :slug, with: ->(slug) { slug.strip.downcase }

  validates :slug, presence: true, format: { with: FORMAT }
  validates :slug, uniqueness: { conditions: -> { in_use } }, unless: :released?
  validates :redirect_until, presence: true, if: :redirecting?
  validate :slug_not_reserved, on: :create
  validate :brand_owns_a_subdomain, on: :create

  after_commit :expire_host_lookup

  def self.reserved?(slug)
    RESERVED.include?(slug) || ReservedSlug.exists?(slug: slug)
  end

  def expire_host_lookup
    Brands::HostLookup.expire(slug)
  end

  private

  def slug_not_reserved
    errors.add(:slug, :reserved) if slug.present? && self.class.reserved?(slug)
  end

  # Only partners and direct companies have a subdomain; a partner's company uses
  # the partner's (D-154).
  def brand_owns_a_subdomain
    owner = brand&.owner
    return if owner.is_a?(Partner) || (owner.is_a?(Company) && owner.direct?)

    errors.add(:brand, :without_subdomain)
  end
end
