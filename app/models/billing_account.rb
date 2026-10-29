# The contract: who pays the CatalystHR (RN-19-001). A partner, for its whole portfolio,
# or a direct company. A partner's company has no contract of its own. The responsible
# is the partner's administrator or the direct company's HR administrator invited at the
# registration, who may add a billing e-mail (RN-19-044). The cycle is monthly, on the
# day the contract started, with days 29 to 31 becoming 28 (RN-19-040, P-19-11).
class BillingAccount < ApplicationRecord
  audited

  OWNER_TYPES = %w[Partner Company].freeze
  LAST_CYCLE_DAY = 28
  # The billing address, the NFS-e's customer at Asaas (RN-19-103, D-635): required at the
  # registration and before the first payment; the complement is optional.
  ADDRESS_FIELDS = %i[postal_code street street_number complement district city state].freeze
  REQUIRED_ADDRESS_FIELDS = (ADDRESS_FIELDS - %i[complement]).freeze

  belongs_to :owner, polymorphic: true
  belongs_to :responsible_user, class_name: "User", optional: true
  has_one :subscription, dependent: :restrict_with_exception
  has_many :invoices, dependent: :restrict_with_exception
  has_many :prorations, dependent: :restrict_with_exception
  has_many :billing_adjustments, dependent: :restrict_with_exception

  normalizes :billing_email, with: ->(email) { email.to_s.strip.downcase.presence }
  normalizes :postal_code, with: ->(code) { code.to_s.gsub(/\D/, "").presence }
  normalizes :street, :street_number, :complement, :district, :city, with: ->(value) { value.to_s.squish.presence }
  normalizes :state, with: ->(state) { state.to_s.strip.upcase.presence }

  validates :owner_type, inclusion: { in: OWNER_TYPES }
  validates :postal_code, format: { with: Unit::POSTAL_CODE_FORMAT }, allow_nil: true
  validates :state, inclusion: { in: Unit::STATES }, allow_nil: true
  validates(*REQUIRED_ADDRESS_FIELDS, presence: true, on: :billing_address)
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

  def billing_address_complete?
    REQUIRED_ADDRESS_FIELDS.all? { |field| public_send(field).present? }
  end

  # The direct company's form comes filled with the headquarters' address while the
  # contract has none; the two stay apart afterwards (D-635). Assigns, without saving.
  def suggest_headquarters_address
    return self if ADDRESS_FIELDS.any? { |field| public_send(field).present? } || partner?

    headquarters = owner.headquarters
    return self unless headquarters&.postal_code

    assign_attributes(ADDRESS_FIELDS.index_with { |field| headquarters.public_send(field) })
    self
  end

  # "Rua Padre Fernando Pedreira de Castro, 30 - Jurubatuba - São Paulo/SP - CEP 04696-180"
  def billing_address_line
    return unless billing_address_complete?

    [ [ street, street_number, complement ].compact.join(", "), district, "#{city}/#{state}",
      "CEP #{postal_code.sub(/\A(\d{5})(\d{3})\z/, '\1-\2')}" ].join(" - ")
  end

  def brand
    owner.brand
  end

  # The billing e-mail (RN-19-044), or the responsible's: the PIX payer and the NFS-e's
  # customer at Asaas (D-636).
  def contact_email
    billing_email || responsible_user&.email || notice_recipients.first&.user&.email
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
