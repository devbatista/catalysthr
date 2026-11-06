# The daily e-mail with the person's work notices (spec 15, RN-15-040 to RN-15-044, D-404,
# D-655): one per membership and brand, so each goes with its own brand. Not tenant-scoped,
# as the notices it lists.
class NotificationDigest < ApplicationRecord
  belongs_to :recipient_membership, class_name: "Membership"
  belongs_to :brand, optional: true
  has_many :deliveries, class_name: "NotificationDelivery", foreign_key: :digest_id, inverse_of: :digest, dependent: nil

  def notifications = Notification.where(id: notification_ids).newest_first
end
