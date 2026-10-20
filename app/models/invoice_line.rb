# A line of an invoice (spec 19, section 7): what is charged, how many and for how much.
# The description is written in Portuguese when the invoice is issued and never changes.
class InvoiceLine < ApplicationRecord
  KINDS = %w[plan module add_on overage_employees overage_ai overage_whatsapp proration adjustment].freeze

  belongs_to :invoice, inverse_of: :lines
  # The proration the line charges, once (D-620), or the manual adjustment it applies (D-621).
  belongs_to :proration, optional: true
  belongs_to :billing_adjustment, optional: true

  enum :kind, KINDS.index_by(&:itself), prefix: true, validate: true

  validates :position, :description, :quantity, :unit_cents, :total_cents, presence: true

  def readonly?
    persisted? || super
  end
end
