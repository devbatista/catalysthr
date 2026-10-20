# The contract: who pays the CatalystHR (RN-19-001). A partner, for its whole portfolio,
# or a direct company. A partner's company has no contract of its own. The responsible
# is the partner's administrator or the direct company's HR administrator invited at the
# registration, who may add a billing e-mail (RN-19-044). The cycle is monthly, on the
# day the contract started, with days 29 to 31 becoming 28 (RN-19-040, P-19-11).
class BillingAccount < ApplicationRecord
  audited

  OWNER_TYPES = %w[Partner Company].freeze
  LAST_CYCLE_DAY = 28

  belongs_to :owner, polymorphic: true
  belongs_to :responsible_user, class_name: "User", optional: true
  has_one :subscription, dependent: :restrict_with_exception
  has_many :invoices, dependent: :restrict_with_exception

  normalizes :billing_email, with: ->(email) { email.to_s.strip.downcase.presence }

  validates :owner_type, inclusion: { in: OWNER_TYPES }
  validates :owner_id, uniqueness: { scope: :owner_type }
  validates :cycle_day, numericality: { only_integer: true, in: 1..LAST_CYCLE_DAY }
  validates :billing_email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_nil: true
  validate :direct_company, if: -> { owner.is_a?(Company) }

  scope :ordered, -> { order(:created_at) }

  def self.cycle_day_for(date)
    [ date.day, LAST_CYCLE_DAY ].min
  end

  def partner?
    owner_type == "Partner"
  end

  def name
    owner.name
  end

  def brand
    owner.brand
  end

  # Who gets the contract's notices: the responsible (RN-19-044), even before accepting the
  # invitation; when they no longer have access to the owner, its administrators.
  def notice_recipients
    memberships = Membership.where(status: [ "invited", *Membership::ACCESS_STATUSES ], organization: owner).includes(:user)
    responsible = memberships.find_by(user_id: responsible_user_id) if responsible_user_id
    return [ responsible ] if responsible

    memberships.where(status: "active").with_role(partner? ? "partner_admin" : "hr_admin").to_a
  end

  private

  # A partner's company is billed through the partner (RN-19-001).
  def direct_company
    errors.add(:owner, :partner_company) if owner.partner_id.present?
  end
end
