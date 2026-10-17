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

  # The employer: a company, identified by the CNPJ root, or a person, by the CPF
  # (RN-04-001, D-200, D-600). Only the superadmin corrects it (D-601).
  EMPLOYER_TYPES = %w[company person].freeze
  CNPJ_ROOT_FORMAT = /\A[0-9A-Z]{8}\z/

  has_many :units, dependent: :restrict_with_error

  # The full CNPJ now lives in the headquarters unit (D-600); the column goes away in a
  # later release.
  self.ignored_columns += [ "cnpj" ]

  encrypts :document, deterministic: true
  enum :employer_type, EMPLOYER_TYPES.index_by(&:itself), validate: true

  normalizes :document, with: ->(document) { document.to_s.gsub(/[^0-9A-Za-z]/, "").upcase }

  before_validation :default_brand_display_mode
  after_create :create_headquarters

  validates :name, :legal_name, presence: true
  validates :document, presence: true, uniqueness: true
  validate :document_format
  validates :brand_display_mode, absence: true, unless: :partner
  validates :read_only_period_days, numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 3650 }

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

  # Search of the admin area: by name, or by the employer's document typed as the CNPJ
  # (full or root) or the CPF.
  def self.matching(query)
    by_name = where("companies.name ILIKE ?", "%#{sanitize_sql_like(query)}%")
    document = query.to_s.gsub(/[^0-9A-Za-z]/, "").upcase
    document = document[0, 8] if document.length == 14
    document.length.in?([ 8, 11 ]) ? by_name.or(where(document: document)) : by_name
  end

  def direct?
    partner_id.nil?
  end

  def headquarters
    ActsAsTenant.with_tenant(self) { units.find_by(headquarters: true) }
  end

  # The document as shown: "12.ABC.345" for a CNPJ root, "123.456.789-09" for a CPF.
  def formatted_document
    return document.to_s.sub(/\A(.{3})(.{3})(.{3})(.{2})\z/, '\1.\2.\3-\4') if person?

    document.to_s.sub(/\A(.{2})(.{3})(.{3})\z/, '\1.\2.\3')
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

  def document_format
    return if document.blank?

    valid = person? ? Cpf.valid?(document) : document.match?(CNPJ_ROOT_FORMAT)
    errors.add(:document, person? ? :invalid_cpf : :invalid_cnpj_root) unless valid
  end

  # Every company has its headquarters, created with it (RN-04-010, P-04-05).
  def create_headquarters
    ActsAsTenant.with_tenant(self) { units.create!(name: Unit::HEADQUARTERS_NAME, headquarters: true) }
  end
end
