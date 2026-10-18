# A notice to a person (spec 15). It shows in the bell when its type has the "system"
# channel (D-608), and goes out through the external channels as deliveries. Not
# tenant-scoped: every query names the recipient, and the bell shows only what belongs
# to the area and the brand being accessed (spec 01, RN-01-013).
class Notification < ApplicationRecord
  # The bell lists the last 90 days (RN-15-001); after 1 year the notice is deleted with
  # its deliveries (RN-15-090, D-608).
  BELL_DAYS = 90
  RETENTION = 1.year
  # The same type, person and origin make one notice in 12 hours (RN-15-085).
  DEDUP_WINDOW = 12.hours
  AREAS = %w[panel admin].freeze

  belongs_to :company, optional: true
  belongs_to :recipient_user, class_name: "User"
  belongs_to :recipient_membership, class_name: "Membership", optional: true
  belongs_to :brand, optional: true
  belongs_to :subject, polymorphic: true, optional: true
  has_many :deliveries, class_name: "NotificationDelivery", dependent: :delete_all

  validates :notification_type, inclusion: { in: ->(_) { NotificationType::CATALOG.keys } }
  validates :area, inclusion: { in: AREAS }, allow_nil: true
  validates :title, :path, presence: true
  # Only paths inside the platform: the bell redirects to it (no open redirect).
  validates :path, format: { with: %r{\A/(?![/\\])\S*\z} }

  scope :in_bell, -> { where(in_bell: true, archived_at: nil).where(created_at: BELL_DAYS.days.ago..) }
  scope :unread, -> { where(read_at: nil) }
  scope :newest_first, -> { order(created_at: :desc, id: :desc) }

  # What the person sees in the area being accessed. In the admin, the notices of the
  # admin. In a brand's panel, those of the person's memberships in the brand, plus the
  # account's own notices of this brand or of no brand (RN-01-013).
  def self.visible_to(user, area:, brand: nil)
    mine = where(recipient_user: user, area: [ area.to_s, nil ])
    return mine.where(recipient_membership_id: nil) if area.to_sym == :admin

    memberships = Membership.for_brand(brand).where(user: user).select(:id)
    mine.where(recipient_membership_id: memberships)
      .or(mine.where(recipient_membership_id: nil, brand_id: [ brand&.id, nil ]))
  end

  def type = NotificationType.find(notification_type)

  def read? = read_at.present?

  def read!
    update_columns(read_at: Time.current) unless read?
  end

  # Absolute link of the e-mails: opens the notice, which marks it read and goes to its
  # page (RN-15-001), at the host where the person signs in.
  def url
    route = "/notifications/#{id}"
    if area == "admin" then PlatformUrl.admin(route)
    elsif brand&.active_subdomain then brand.panel_url(route)
    end
  end
end
