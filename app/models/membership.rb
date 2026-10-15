# The link between a person and a company, partner or accounting firm, with one or
# more roles (D-050 to D-052, P-02-36). Memberships cross companies, so they are not
# tenant-scoped: every query names its organization.
class Membership < ApplicationRecord
  # Roles per kind of organization (P-02-02).
  ROLES = {
    "Company" => %w[hr_admin hr_analyst manager employee client_manager],
    "Partner" => %w[partner_admin consultant],
    "AccountingFirm" => %w[firm_admin accountant]
  }.freeze
  # Statuses that let the person in (RN-02-004). Read-only shows only the person's
  # own records (D-090).
  ACCESS_STATUSES = %w[active read_only].freeze

  belongs_to :user
  belongs_to :organization, polymorphic: true

  # RN-02-060: invited → active ⇄ suspended → read_only → revoked.
  enum :status, {
    invited: "invited",
    active: "active",
    suspended: "suspended",
    read_only: "read_only",
    revoked: "revoked"
  }, validate: true

  normalizes :roles, with: ->(roles) { roles.compact_blank.map(&:to_s).uniq }

  validates :organization_type, inclusion: { in: ROLES.keys }
  validates :user_id, uniqueness: { scope: [ :organization_type, :organization_id ] }
  validate :roles_of_organization

  scope :with_access, -> { where(status: ACCESS_STATUSES) }

  # Memberships a brand's subdomain considers at sign-in (RN-01-002): the partner's
  # own and its companies', or the direct company's. A partner's company is always
  # reached through the partner's subdomain (D-154).
  def self.for_brand(brand)
    case brand&.owner
    when Partner
      partner = brand.owner
      where(organization: partner).or(where(organization_type: "Company", organization_id: partner.companies.select(:id)))
    when Company
      brand.owner.direct? ? where(organization: brand.owner) : none
    else
      none
    end
  end

  private

  def roles_of_organization
    allowed = ROLES.fetch(organization_type, [])
    errors.add(:roles, :blank) if roles.empty?
    errors.add(:roles, :not_allowed) if (roles - allowed).any?
    # The client's manager has no other role in the company (P-02-38).
    errors.add(:roles, :client_manager_alone) if roles.include?("client_manager") && roles.size > 1
  end
end
