# The sending of a notice through an external channel (spec 15, sections 4.9 and 5). It
# keeps the masked destination and the statuses, never the text (RN-15-090).
class NotificationDelivery < ApplicationRecord
  CHANNELS = %w[email push].freeze

  belongs_to :notification
  # The failed delivery this one replaces (RN-15-081).
  belongs_to :fallback_from, class_name: "NotificationDelivery", optional: true
  # The delivery whose message speaks for this one too, released together (RN-15-034).
  belongs_to :grouped_into, class_name: "NotificationDelivery", optional: true
  has_many :grouped, class_name: "NotificationDelivery", foreign_key: :grouped_into_id, inverse_of: :grouped_into, dependent: nil

  # queued → (held, in the quiet hours)? → sending → sent → delivered | failed, or
  # cancelled when read in the system first (RN-15-035). The fallback is a new delivery.
  enum :status, { queued: "queued", held: "held", sending: "sending", sent: "sent", delivered: "delivered", failed: "failed",
    cancelled: "cancelled" }, validate: true

  validates :channel, inclusion: { in: CHANNELS }

  # Whatever made it fail, a job or a provider's event, a mandatory notice moves on (RN-15-081).
  after_update_commit :fall_back, if: -> { saved_change_to_status? && failed? && notification.mandatory }

  # "an***@example.com": enough to tell which address, never the whole of it.
  def self.mask_email(email)
    local, domain = email.to_s.split("@", 2)
    return if domain.blank?

    "#{local.first(2)}***@#{domain}"
  end

  private

  def fall_back
    Notifications::FallbackJob.perform_later(self)
  end
end
