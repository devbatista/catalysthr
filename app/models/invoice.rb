# The invoice of a contract's monthly cycle (RN-19-040, RN-19-041, D-619): issued 3 days
# before the cycle starts, due on its first day, with every line detailed. The first cycle's
# invoice is issued when the contract is registered and is due that day. Amounts never
# change once issued; the statuses after `open` come with the payment and dunning blocks
# (19e, 19f). Not tenant-scoped: the contract belongs to a partner or a direct company, and
# every query names the contract.
class Invoice < ApplicationRecord
  audited

  STATUSES = %w[draft open paid overdue void].freeze

  belongs_to :billing_account
  has_many :lines, -> { order(:position) }, class_name: "InvoiceLine", inverse_of: :invoice, dependent: :restrict_with_exception

  enum :status, STATUSES.index_by(&:itself), validate: true

  validates :number, :period_start, :period_end, :due_on, :total_cents, :issued_at, presence: true

  scope :recent_first, -> { order(due_on: :desc, number: :desc) }

  # "000123".
  def display_number
    number.to_s.rjust(6, "0")
  end
end
