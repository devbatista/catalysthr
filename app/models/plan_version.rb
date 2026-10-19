# The prices, limits and quotas of a plan from a date (RN-19-010, RN-19-014, D-611). A
# version never changes: a new price is a new version, and contracts keep theirs until the
# finance team migrates them. A future version is corrected by another of the same date;
# between versions of the same date, the one registered last is in force. Amounts are
# typed in reais and kept in cents.
class PlanVersion < ApplicationRecord
  include TypedAmounts

  audited

  # Partner plan (D-480): fixed price for a band of employees, with overage above it.
  PARTNER_AMOUNTS = %i[monthly_price overage_per_employee].freeze
  PARTNER_QUANTITIES = %i[employee_limit ai_credits whatsapp_messages].freeze
  # Direct company plan (D-122): price per active employee, with a monthly minimum, and
  # quotas per employee.
  DIRECT_AMOUNTS = %i[price_per_employee minimum_monthly].freeze
  DIRECT_QUANTITIES = %i[ai_credits_per_employee whatsapp_messages_per_employee].freeze
  # Price of the AI credit and of the WhatsApp message above the quota, in both kinds.
  SHARED_AMOUNTS = %i[ai_credit_overage whatsapp_overage].freeze

  typed_amounts(*PARTNER_AMOUNTS, *DIRECT_AMOUNTS, *SHARED_AMOUNTS)

  belongs_to :plan, inverse_of: :plan_versions
  belongs_to :created_by, class_name: "User"
  # The modules are validated by every_module, with messages that name the module.
  has_many :plan_modules, -> { order(:module) }, inverse_of: :plan_version, dependent: :restrict_with_exception, validate: false

  before_validation :assign_version, on: :create
  before_validation :clear_other_kind

  validates :version, numericality: { only_integer: true, greater_than: 0 }
  validates :valid_from, presence: true
  validates :employee_limit, numericality: { only_integer: true, greater_than: 0 }, if: -> { plan&.partner? }
  validates(*(PARTNER_QUANTITIES - [ :employee_limit ]), numericality: { only_integer: true, greater_than_or_equal_to: 0 }, if: -> { plan&.partner? })
  validates(*DIRECT_QUANTITIES, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, if: -> { plan&.direct? })
  validate :amounts_of_the_kind
  validate :not_in_the_past, on: :create
  validate :every_module

  # A new version starting from another one: same values, for the person to change.
  def self.based_on(plan, version)
    attributes = version&.attributes&.except("id", "plan_id", "version", "valid_from", "created_by_id", "created_at", "updated_at")
    new(attributes.to_h.merge(plan: plan, valid_from: Date.current)).tap do |copy|
      version&.plan_modules&.each { |plan_module| copy.plan_modules.new(module: plan_module.module, price_cents: plan_module.price_cents) }
    end
  end

  def readonly?
    persisted? || super
  end

  # The modules' prices typed in reais, by module code.
  def module_prices=(prices)
    plan_modules.clear
    PlanModule::MODULES.each do |code|
      plan_modules.new(module: code, price: prices.to_h.with_indifferent_access[code])
    end
  end

  def plan_module(code)
    plan_modules.find { |plan_module| plan_module.module == code }
  end

  def amounts
    (plan&.partner? ? PARTNER_AMOUNTS : DIRECT_AMOUNTS) + SHARED_AMOUNTS
  end

  def quantities
    plan&.partner? ? PARTNER_QUANTITIES : DIRECT_QUANTITIES
  end

  private

  # Two versions saved at the same moment are stopped by the unique index.
  def assign_version
    self.version ||= (PlanVersion.where(plan_id: plan_id).maximum(:version) || 0) + 1
  end

  # A version holds only the fields of its plan's kind.
  def clear_other_kind
    return if plan.nil?

    others = plan.partner? ? DIRECT_AMOUNTS.map { |field| :"#{field}_cents" } + DIRECT_QUANTITIES : PARTNER_AMOUNTS.map { |field| :"#{field}_cents" } + PARTNER_QUANTITIES
    others.each { |field| self[field] = nil }
  end

  def amounts_of_the_kind
    return if plan.nil?

    amounts.each { |field| errors.add(:"#{field}_cents", :blank) if public_send(:"#{field}_cents").nil? && !invalid_amount?(field) }
  end

  # A version takes effect today or later: a past price would change what was already sold.
  def not_in_the_past
    errors.add(:valid_from, :past) if valid_from && valid_from < Date.current
  end

  def every_module
    errors.add(:plan_modules, :incomplete) unless plan_modules.map(&:module).sort == PlanModule::MODULES.sort
    plan_modules.each do |plan_module|
      next if plan_module.valid?

      plan_module.errors.each { |error| errors.add(:base, :module_price, module: I18n.t("modules.#{plan_module.module}"), problem: error.message) }
    end
  end
end
