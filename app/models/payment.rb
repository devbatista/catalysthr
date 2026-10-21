# A payment of an invoice in Mercado Pago (spec 19, RN-19-042, D-622): for now, a PIX order
# with its QR code, due at the end of the invoice's due date. A PIX that expires or is
# replaced is `cancelled`; the card comes with block 19h.
class Payment < ApplicationRecord
  audited

  METHODS = %w[pix card].freeze
  STATUSES = %w[pending approved rejected refunded cancelled].freeze

  belongs_to :invoice

  enum :status, STATUSES.index_by(&:itself), validate: true

  validates :payment_method, inclusion: { in: METHODS }
  validates :amount_cents, numericality: { only_integer: true, greater_than: 0 }
  validates :idempotency_key, presence: true

  scope :pix, -> { where(payment_method: "pix") }

  # Still payable at `time`: pending, with its QR code, before it expires.
  def live?(time = Time.current)
    pending? && qr_code.present? && expires_at.present? && expires_at > time
  end
end
