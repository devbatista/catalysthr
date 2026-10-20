# The plan version, modules and add-ons a contract has, with its status (RN-19-002). The
# trial lasts 14 days (RN-19-030, D-485). A partner under contract pays the pre-activation
# fee kept here until the first active employee in the portfolio (RN-19-035, D-612);
# activated_on marks that day, and a direct company is active from the start. The
# transitions between statuses come with the blocks that cause them (D-610, D-613).
class Subscription < ApplicationRecord
  audited

  STATUSES = %w[trialing active past_due read_only closing closed trial_expired cancel_scheduled].freeze
  TRIAL_DAYS = 14
  # The reduced quotas of the trial, also used in the partner's pre-activation (RN-19-031,
  # P-19-09, D-612).
  REDUCED_AI_CREDITS = 100
  REDUCED_WHATSAPP_MESSAGES = 100

  belongs_to :billing_account
  belongs_to :plan_version
  belongs_to :pre_activation_price, optional: true
  belongs_to :created_by, class_name: "User"
  has_many :items, -> { order(:id) }, class_name: "SubscriptionItem", inverse_of: :subscription, dependent: :restrict_with_exception

  enum :status, STATUSES.index_by(&:itself), validate: true

  validates :started_on, presence: true
  validates :trial_ends_on, presence: true, if: :trialing?
  validates :pre_activation_price, presence: true, if: :pre_activation?
  validate :plan_of_the_owner

  delegate :plan, to: :plan_version

  # A partner under contract before the first active employee (D-612).
  def pre_activation?
    billing_account&.partner? && !trialing? && !trial_expired? && activated_on.nil?
  end

  def modules
    items.select { |item| item.kind_module? && item.current? }.map(&:module)
  end

  # The partner's band of employees (D-480), not charged in the pre-activation (D-612). A
  # direct company has none (RN-19-010).
  def employee_band
    plan_version.employee_limit unless pre_activation?
  end

  # The partner's monthly quotas: the plan's, or the reduced ones in the trial and in the
  # pre-activation. The direct company's are per employee and come with the invoices
  # (block 19d).
  def partner_quotas
    return unless billing_account.partner?
    return { ai_credits: REDUCED_AI_CREDITS, whatsapp_messages: REDUCED_WHATSAPP_MESSAGES } if reduced_quotas?

    { ai_credits: plan_version.ai_credits, whatsapp_messages: plan_version.whatsapp_messages }
  end

  def reduced_quotas?
    trialing? || trial_expired? || pre_activation?
  end

  def add_on_prices
    items.select { |item| item.kind_add_on? && item.current? }.map(&:add_on_price)
  end

  private

  def plan_of_the_owner
    return if plan_version.nil? || billing_account.nil?

    expected = billing_account.partner? ? "partner" : "direct"
    errors.add(:plan_version, :other_kind) unless plan_version.plan.kind == expected
  end
end
