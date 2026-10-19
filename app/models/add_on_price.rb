# A version of an add-on's monthly price (RN-19-013, D-611). Never changes: a new price is
# a new version, valid for new contracts from its date, and contracts keep theirs until the
# finance team migrates them with 30 days' notice (RN-19-014).
class AddOnPrice < ApplicationRecord
  include TypedAmounts
  include VersionedPrice

  audited

  typed_amounts :monthly_price
  versioned_price scope: :add_on_id

  belongs_to :add_on, inverse_of: :prices
  belongs_to :created_by, class_name: "User"

  validates :monthly_price_cents, presence: true, unless: -> { invalid_amount?(:monthly_price) }
end
