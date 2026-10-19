# The tenant (D-151). A company either belongs to a partner, and is reached through
# the partner's subdomain (D-154), or is a direct company with its own brand and
# subdomain (D-121).
class Company < ApplicationRecord
  audited

  belongs_to :partner, optional: true
  # Own brand: required for a direct company to get a subdomain; optional for a
  # partner's company, shown according to brand_display_mode (D-163, RN-01-034).
  has_one :brand, as: :owner, dependent: :destroy
  # The contract, for partners and direct companies (RN-19-001).
  has_one :billing_account, as: :owner, dependent: :restrict_with_exception
  # The modules the partner turned on for the company (RN-19-012, D-616).
  has_many :module_settings, class_name: "CompanyModuleSetting", dependent: :restrict_with_exception

  enum :brand_display_mode, { alongside: "alongside", replace: "replace" },
    prefix: :brand, validate: { allow_nil: true }

  # The employer: a company, identified by the CNPJ root, or a person, by the CPF
  # (RN-04-001, D-200, D-600). Only the superadmin corrects it (D-601).
  EMPLOYER_TYPES = %w[company person].freeze
  CNPJ_ROOT_FORMAT = /\A[0-9A-Z]{8}\z/

  has_many :units, dependent: :restrict_with_error

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
  validate :allocation_clients_off_when_unused, if: -> { uses_allocation_clients_changed? && !uses_allocation_clients }
  validates :next_registration_number, numericality: { only_integer: true, greater_than: 0, less_than: 10**15 }

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

  # A company registered by its CNPJ: the employer is identified by the CNPJ root, and
  # the full CNPJ goes to the headquarters (RN-04-001, RN-04-010, D-600).
  def self.create_with_cnpj!(cnpj:, **attributes)
    number = Cnpj.normalize(cnpj)
    company = create!(employer_type: "company", document: number[0, 8], **attributes)
    ActsAsTenant.with_tenant(company) { company.headquarters.update!(registration_type: "cnpj", registration_number: number) }
    company
  end

  def direct?
    partner_id.nil?
  end

  # The modules the contract allows (P-03-12, D-616).
  def contract_modules
    @contract_modules ||= CompanyModules.new(self)
  end

  def reload(*)
    @contract_modules = nil
    super
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

  # The registration number suggested for a new employment: the next sequential one not
  # used by any employment of the company, ended ones included (RN-04-052, D-211).
  def suggested_registration_number
    ActsAsTenant.with_tenant(self) do
      numeric = "CASE WHEN registration_number ~ '^[0-9]{1,15}$' THEN registration_number::bigint END"
      taken = Employment.where("#{numeric} >= ?", next_registration_number).pluck(:registration_number).to_set(&:to_i)
      number = next_registration_number
      number += 1 while taken.include?(number)
      number.to_s
    end
  end

  # After a numeric registration number at or past the sequence is used, the sequence
  # moves on.
  def advance_registration_number!(used)
    return unless used.to_s.match?(/\A\d{1,15}\z/) && used.to_i >= next_registration_number

    update!(next_registration_number: used.to_i + 1)
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

  # Allocation clients are turned off only with no open employment allocated, now or
  # from a future date (RN-04-090, P-04-30).
  def allocation_clients_off_when_unused
    allocated = ActsAsTenant.with_tenant(self) { EmploymentRevision.placing_open_employments.where.not(allocation_client_id: nil).exists? }
    errors.add(:uses_allocation_clients, :in_use) if allocated
  end

  # Every company has its headquarters, created with it (RN-04-010, P-04-05).
  def create_headquarters
    ActsAsTenant.with_tenant(self) { units.create!(name: Unit::HEADQUARTERS_NAME, headquarters: true) }
  end
end
