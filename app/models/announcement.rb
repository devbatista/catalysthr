# A notice of the HR on the board (spec 15, RN-15-070 to RN-15-074, D-408, D-656): the title,
# the text, an optional PDF or image, the audience, when it goes up and until when it stays.
# The audience is the filter as chosen, and who it reaches is read when someone opens the
# board, so who joins later sees it while it is in force (D-656). It has no value of
# acknowledgment (RN-15-073, P-15-23). Draft and scheduled ones change freely; a published one
# changes only its validity and the pin, so the board says what the notice said (D-656).
class Announcement < ApplicationRecord
  acts_as_tenant :company

  audited

  STATUSES = %w[draft scheduled published expired withdrawn].freeze
  # The attachment (RN-15-071): a PDF or an image, checked by its content.
  ATTACHMENT_TYPES = %w[application/pdf image/jpeg image/png].freeze
  MAX_ATTACHMENT_SIZE = 10.megabytes
  MAX_BODY = 5_000
  # The validity the form suggests (D-656).
  DEFAULT_DAYS = 30
  # In the board's history after the validity, or after it was withdrawn (RN-15-091).
  RETENTION = 2.years

  belongs_to :author, class_name: "User"
  belongs_to :withdrawn_by, class_name: "User", optional: true
  has_one_attached :attachment
  has_many :reads, class_name: "AnnouncementRead", dependent: :delete_all

  enum :status, STATUSES.index_by(&:itself), validate: true

  normalizes :title, with: ->(title) { title.to_s.squish.presence }
  normalizes :body, with: ->(text) { text.to_s.strip.gsub("\r\n", "\n").presence }

  validates :title, presence: true, length: { maximum: 160 }
  validates :body, presence: true, length: { maximum: MAX_BODY }
  validates :expires_at, presence: true
  validates :publish_at, presence: true, if: :scheduled?
  validate :expires_after_publication

  # On the board now (RN-15-071): published and in force.
  scope :live, -> { published.where("announcements.expires_at > ?", Time.current) }
  # The board's history (RN-15-091): those that reached the end of their validity.
  scope :past, -> { where(status: %w[published expired]).where(announcements: { expires_at: ..Time.current }) }
  scope :board_order, -> { order(pinned: :desc, published_at: :desc) }
  # Past the history's two years (RN-15-091), counted from the withdrawal or the validity.
  scope :past_retention, -> { where("COALESCE(announcements.withdrawn_at, announcements.expires_at) < ?", RETENTION.ago) }

  # The notices of the board a person sees: those whose audience reaches one of their open
  # employments (CA-15-011).
  def self.reaching(profile)
    clauses = Announcements::Audience.places(profile).map do |place|
      Announcements::Audience::COLUMNS.map do |key, value|
        sanitize_sql_array([ "(announcements.audience -> '#{key}' IS NULL OR announcements.audience -> '#{key}' @> to_jsonb(CAST(? AS text)))",
          place[value] ])
      end.join(" AND ")
    end
    clauses.empty? ? none : where(clauses.map { |clause| "(#{clause})" }.join(" OR "))
  end

  # The HR's board in the panel: the HR analyst sees those for everyone and those of their
  # units (D-656); unit_ids is :all for the others.
  def self.in_panel(unit_ids)
    return all if unit_ids == :all

    where("announcements.audience -> 'unit_ids' IS NULL OR announcements.audience -> 'unit_ids' ?| ARRAY[:ids]::text[]",
      ids: unit_ids.map(&:to_s).presence || [ "" ])
  end

  def audit_company_id
    company_id
  end

  def audience_filter
    Announcements::Audience.new(audience)
  end

  def live?
    published? && expires_at > Time.current
  end

  # Text, attachment and audience change only before it goes up (D-656).
  def content_editable?
    draft? || scheduled?
  end

  def withdrawable?
    !withdrawn? && !expired?
  end

  # The attachment's scan (P-05-30): only a clean one is served.
  def scan_status
    return "clean" unless attachment.attached?

    attachment.blob.file_scan&.status || "scanning"
  end

  def attachment_clean?
    attachment.attached? && scan_status == "clean"
  end

  private

  def expires_after_publication
    return if expires_at.nil?

    start = scheduled? ? publish_at : nil
    errors.add(:expires_at, :after_publication) if start && expires_at <= start
    errors.add(:expires_at, :past) if will_save_change_to_expires_at? && expires_at <= Time.current
  end
end
