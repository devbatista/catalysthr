# A version of an add-on's monthly price (RN-19-013, D-611). Never changes: a new price is
# a new version, valid for new contracts from its date, and contracts keep theirs until the
# finance team migrates them with 30 days' notice (RN-19-014).
class AddOnPrice < ApplicationRecord
  include TypedAmounts

  audited

  typed_amounts :monthly_price

  belongs_to :add_on, inverse_of: :prices
  belongs_to :created_by, class_name: "User"

  before_validation :assign_version, on: :create

  validates :version, numericality: { only_integer: true, greater_than: 0 }
  validates :valid_from, presence: true
  validates :monthly_price_cents, presence: true, unless: -> { invalid_amount?(:monthly_price) }
  validate :not_in_the_past, on: :create

  def readonly?
    persisted? || super
  end

  private

  # Two prices saved at the same moment are stopped by the unique index.
  def assign_version
    self.version ||= (AddOnPrice.where(add_on_id: add_on_id).maximum(:version) || 0) + 1
  end

  def not_in_the_past
    errors.add(:valid_from, :past) if valid_from && valid_from < Date.current
  end
end
