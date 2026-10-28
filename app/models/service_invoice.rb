# The NFS-e of a paid invoice, issued through Asaas (spec 19, section 4.11, D-633). Born
# `pending` when the payment is confirmed; `scheduled` once Asaas takes it, for the day in
# `effective_on`; `authorized` when the city authorizes it (block 19i-3); `error` when
# Asaas or the city refuses it, until the finance team issues it again (RN-19-108). A refund
# cancels it (RN-19-110): `cancelling` while the city processes it, then `cancelled`, or
# `cancel_denied` when the city refuses, for the team to settle with the accountant. Not
# tenant-scoped, like the invoice.
class ServiceInvoice < ApplicationRecord
  audited

  STATUSES = %w[pending scheduled authorized error cancelling cancelled cancel_denied].freeze

  belongs_to :invoice
  # The authorized note's files, in the private bucket (RN-19-107).
  has_one_attached :pdf
  has_one_attached :xml

  enum :status, STATUSES.index_by(&:itself), validate: true

  def files_missing?
    !(pdf.attached? && xml.attached?)
  end

  validates :amount_cents, numericality: { only_integer: true, greater_than: 0 }
  validates :competence_on, presence: true
end
