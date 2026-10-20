# A manual adjustment of a contract's next invoices (RN-19-070, RN-19-071, D-491, D-621),
# launched by the finance team or the superadmin with a mandatory reason:
# - discount: a value or a percent of the whole invoice before adjustments, in one cycle or
#   in several, one invoice each;
# - credit: a value that reduces the next invoices until it runs out;
# - overage waiver: the overage of the next invoice, of employees, AI, WhatsApp or all.
# Above 20% of the next invoice's preview, a finance team's adjustment waits for the
# superadmin's approval. An adjustment applies only once approved, and an invoice never goes
# below zero. Amounts are typed in reais and kept in cents.
class BillingAdjustment < ApplicationRecord
  include TypedAmounts

  audited

  KINDS = %w[discount credit overage_waiver].freeze
  STATUSES = %w[pending approved cancelled].freeze
  # The overage each waiver covers, by the invoice line's kind.
  OVERAGE_SCOPES = {
    "employees" => %w[overage_employees], "ai" => %w[overage_ai], "whatsapp" => %w[overage_whatsapp],
    "all" => %w[overage_employees overage_ai overage_whatsapp]
  }.freeze
  # Above this share of the next invoice, the finance team needs the superadmin (RN-19-071).
  APPROVAL_SHARE = Rational(1, 5)
  MAX_CYCLES = 12

  typed_amounts :value

  belongs_to :billing_account
  belongs_to :created_by, class_name: "User"
  belongs_to :approved_by, class_name: "User", optional: true
  belongs_to :cancelled_by, class_name: "User", optional: true
  has_many :invoice_lines, dependent: :restrict_with_exception

  enum :kind, KINDS.index_by(&:itself), validate: true
  enum :status, STATUSES.index_by(&:itself), validate: true

  normalizes :reason, with: ->(reason) { reason.to_s.strip.presence }

  validates :reason, presence: true, length: { maximum: 1_000 }
  validates :cycles, numericality: { only_integer: true, in: 1..MAX_CYCLES }
  validates :percent, numericality: { greater_than: 0, less_than_or_equal_to: 100 }, allow_nil: true
  validates :overage_scope, inclusion: { in: OVERAGE_SCOPES.keys }, if: :overage_waiver?
  validate :amount_of_the_kind

  scope :newest_first, -> { order(created_at: :desc) }

  # "12,5" as typed in Portuguese.
  def percent=(value)
    super(value.is_a?(String) ? value.strip.tr(",", ".").presence : value)
  end

  # Still to apply on the next invoices.
  def open?
    approved? && !used_up?
  end

  def used_up?
    if credit?
      applied_cents >= value_cents
    else
      invoice_lines.size >= (discount? ? cycles : 1)
    end
  end

  # How much the adjustment already took off the invoices.
  def applied_cents
    -invoice_lines.sum(&:total_cents)
  end

  def remaining_credit_cents
    value_cents - applied_cents
  end

  # Not yet in any invoice: it can still be cancelled.
  def cancellable?
    !cancelled? && invoice_lines.empty?
  end

  private

  # A discount is a value or a percent; a credit is a value; a waiver has neither.
  def amount_of_the_kind
    return if invalid_amount?(:value)

    case kind
    when "discount"
      errors.add(:base, :value_or_percent) unless value_cents.to_i.positive? ^ percent.present?
    when "credit"
      errors.add(:value_cents, :blank) unless value_cents.to_i.positive?
      errors.add(:percent, :present) if percent.present?
    when "overage_waiver"
      errors.add(:base, :waiver_without_amount) if value_cents.present? || percent.present?
    end
    errors.add(:cycles, :one_cycle) if !discount? && cycles.to_i > 1
  end
end
