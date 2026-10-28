# The NFS-e of a paid invoice, issued through Asaas (spec 19, section 4.11, D-633). Born
# `pending` when the payment is confirmed; `scheduled` once Asaas takes it, for the day in
# `effective_on`; `authorized` when the city authorizes it (block 19i-3); `error` when
# Asaas or the city refuses it, until the finance team issues it again (RN-19-108); and
# `cancelled` with a refund (block 19i-4). Not tenant-scoped, like the invoice.
class ServiceInvoice < ApplicationRecord
  audited

  STATUSES = %w[pending scheduled authorized error cancelled].freeze

  belongs_to :invoice

  enum :status, STATUSES.index_by(&:itself), validate: true

  validates :amount_cents, numericality: { only_integer: true, greater_than: 0 }
  validates :competence_on, presence: true
end
