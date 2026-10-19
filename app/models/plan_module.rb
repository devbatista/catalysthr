# The price of a module in a plan version (RN-19-010, RN-19-011, D-111, D-122): fixed and
# added to the monthly price in partner plans, per active employee in direct company
# plans. The codes are the system's own (Membership::RELEASABLE_MODULES); payroll
# includes eSocial (D-111). Never changes, like its version (D-611).
class PlanModule < ApplicationRecord
  include TypedAmounts

  audited

  MODULES = %w[ponto folha].freeze

  typed_amounts :price

  belongs_to :plan_version, inverse_of: :plan_modules

  validates :module, inclusion: { in: MODULES }
  validates :price_cents, presence: true, unless: -> { invalid_amount?(:price) }

  def readonly?
    persisted? || super
  end
end
