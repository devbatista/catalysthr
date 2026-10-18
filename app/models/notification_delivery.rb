# The sending of a notice through an external channel (spec 15, sections 4.9 and 5). It
# keeps the masked destination and the statuses, never the text (RN-15-090).
class NotificationDelivery < ApplicationRecord
  CHANNELS = %w[email].freeze

  belongs_to :notification

  # Phase 1: queued → sending → sent | failed. Delivered, bounced and held come with
  # the SES events (15b) and with phase 2 (D-607).
  enum :status, { queued: "queued", sending: "sending", sent: "sent", delivered: "delivered", failed: "failed",
    cancelled: "cancelled" }, validate: true

  validates :channel, inclusion: { in: CHANNELS }

  # "an***@example.com": enough to tell which address, never the whole of it.
  def self.mask_email(email)
    local, domain = email.to_s.split("@", 2)
    return if domain.blank?

    "#{local.first(2)}***@#{domain}"
  end
end
