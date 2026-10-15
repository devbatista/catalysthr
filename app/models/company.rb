# The tenant (D-151). A company either belongs to a partner, and is reached through
# the partner's subdomain (D-154), or is a direct company with its own brand and
# subdomain (D-121).
class Company < ApplicationRecord
  audited

  belongs_to :partner, optional: true
  # Own brand: required for a direct company to get a subdomain; optional for a
  # partner's company, shown according to brand_display_mode (D-163, RN-01-034).
  has_one :brand, as: :owner, dependent: :destroy

  enum :brand_display_mode, { alongside: "alongside", replace: "replace" },
    prefix: :brand, validate: { allow_nil: true }

  normalizes :cnpj, with: ->(cnpj) { Cnpj.normalize(cnpj) }

  before_validation :default_brand_display_mode

  validates :name, :legal_name, presence: true
  validates :cnpj, presence: true, cnpj: true, uniqueness: true
  validates :brand_display_mode, absence: true, unless: :partner

  def direct?
    partner_id.nil?
  end

  def audit_company_id
    id
  end

  # The brand that owns the subdomain the company is reached through.
  def subdomain_brand
    direct? ? brand : partner.brand
  end

  private

  def default_brand_display_mode
    self.brand_display_mode ||= "alongside" if partner
  end
end
