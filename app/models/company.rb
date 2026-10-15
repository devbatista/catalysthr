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

  # Companies of the brand where the person operates, the only ones the selector lists
  # and accepts (RN-01-005, RN-01-011): those with a membership of the company; for a
  # consultant, the partner's companies assigned to them (D-052, D-192); for an
  # accounting firm's team, the brand's companies with an active link to the firm
  # (RN-02-072, D-586). The partner's administrator without the consultant role does not
  # operate inside companies (P-03-01).
  def self.operable_by(user, brand:)
    memberships = Membership.with_access.for_brand(brand).where(user: user)
    consultants = memberships.active.where(organization_type: "Partner").with_role("consultant")
    assigned = PartnerMembershipCompany.joins(:membership, :company).merge(consultants)
      .where("companies.partner_id = memberships.organization_id")
    firms = memberships.active.where(organization_type: "AccountingFirm").select(:organization_id)
    served = AccountingFirmCompany.active.where(accounting_firm_id: firms, company_id: brand.served_companies.select(:id))

    where(id: memberships.where(organization_type: "Company").select(:organization_id))
      .or(where(id: assigned.select(:company_id)))
      .or(where(id: served.select(:company_id)))
  end

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
