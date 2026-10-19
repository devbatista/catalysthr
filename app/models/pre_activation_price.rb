# The symbolic monthly fee a partner pays until the first active employee in the
# portfolio (RN-19-035, D-612): a single value for every partner plan, with versions like
# the prices (D-611). A subscription keeps the version it was sold with.
class PreActivationPrice < ApplicationRecord
  include TypedAmounts
  include VersionedPrice

  audited

  typed_amounts :monthly_price
  versioned_price

  belongs_to :created_by, class_name: "User"

  validates :monthly_price_cents, presence: true, unless: -> { invalid_amount?(:monthly_price) }

  def self.on(date = Date.current)
    in_force(where(valid_from: ..date).to_a, date)
  end

  def self.latest
    order(:version).last
  end
end
