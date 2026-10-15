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
  # The invitation link is valid for 72 hours (RN-02-012, D-178).
  INVITATION_VALIDITY = 72.hours
  # Channels of the invitation (RN-02-011, D-177). WhatsApp comes with Twilio.
  INVITATION_CHANNELS = %w[email link].freeze

  belongs_to :user
  belongs_to :organization, polymorphic: true
  belongs_to :invited_by, class_name: "User", optional: true

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
  validate :invitation_channels_available

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

  def self.find_by_invitation_token(token)
    return if token.blank?

    find_by(invitation_token_digest: token_digest(token))
  end

  def self.token_digest(token)
    OpenSSL::Digest::SHA256.hexdigest(token)
  end

  # The brand whose subdomain the person uses: the partner's for the partner and its
  # companies (D-154), or the direct company's.
  def subdomain_brand
    organization.is_a?(Company) ? organization.subdomain_brand : organization.brand
  end

  # Sender name of the e-mails. In replace mode, the company's name (P-01-18).
  def sender_name
    company_brand = organization.brand if organization.is_a?(Company) && organization.brand_replace?
    (company_brand || subdomain_brand).commercial_name
  end

  # A new token replaces the previous one, which stops working (RN-02-012, P-02-07).
  # Only its digest is stored; the token itself goes in the link.
  def issue_invitation!(channels:, invited_by:)
    token = SecureRandom.urlsafe_base64(32)
    update!(
      invitation_token_digest: self.class.token_digest(token), invitation_channels: channels,
      invitation_sent_at: Time.current, invitation_expires_at: INVITATION_VALIDITY.from_now,
      invited_by: invited_by
    )
    token
  end

  def invitation_open?
    invited? && invitation_token_digest.present? && invitation_expires_at&.future?
  end

  # The link can be used once (RN-02-012).
  def accept_invitation!
    update!(status: "active", invitation_token_digest: nil)
  end

  def invitation_url(token)
    subdomain_brand.panel_url("/convite", token: token)
  end

  private

  def invitation_channels_available
    errors.add(:invitation_channels, :unavailable) if (invitation_channels - INVITATION_CHANNELS).any?
  end

  def roles_of_organization
    allowed = ROLES.fetch(organization_type, [])
    errors.add(:roles, :blank) if roles.empty?
    errors.add(:roles, :not_allowed) if (roles - allowed).any?
    # The client's manager has no other role in the company (P-02-38).
    errors.add(:roles, :client_manager_alone) if roles.include?("client_manager") && roles.size > 1
  end
end
