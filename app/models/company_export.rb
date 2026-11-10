# The company's full export (spec 18, RN-18-070 to RN-18-075, D-466, D-667): everything of the
# company the system has, in a ZIP protected with AES-256 by a password the system generates.
# The password stays encrypted until the requester opens the ready export, is shown once and
# then erased (D-667). Above 5 GB the ZIP leaves in 7-Zip volumes (D-667). Only who asked sees
# it ready and downloads it, for 7 days (RN-18-073, D-667). At most one per week per company,
# counted from the last request that did not fail (RN-18-074, CA-18-012). The closing's and the
# portability's exports come with the rest of spec 05 (D-661).
class CompanyExport < ApplicationRecord
  STATUSES = %w[queued generating ready expired failed].freeze
  KINDS = %w[full].freeze
  LIFETIME = 7.days
  INTERVAL = 7.days
  PART_SIZE = 5.gigabytes
  FORMAT_VERSION = "1".freeze

  audited secret: %i[password]

  acts_as_tenant :company

  belongs_to :requested_by, class_name: "User"
  has_many_attached :parts

  encrypts :password

  enum :status, STATUSES.index_by(&:itself), validate: true

  validates :kind, inclusion: { in: KINDS }

  scope :counting, -> { where(kind: "full").where.not(status: "failed") }

  # The day the company may ask for another, or nil when it may now (RN-18-074, CA-18-012).
  def self.next_allowed_at(now: Time.current)
    last = counting.maximum(:created_at)
    allowed = last && last + INTERVAL
    allowed if allowed && allowed > now
  end

  def available?
    ready? && expires_at&.future? && parts.attached?
  end

  def password_pending?
    available? && password.present? && password_shown_at.nil?
  end

  # The password, once: it leaves the database as it is shown (RN-18-075, D-667).
  def reveal_password!
    with_lock do
      return unless password_pending?

      shown = password
      update!(password: nil, password_shown_at: Time.current)
      shown
    end
  end

  def ordered_parts
    parts.includes(:blob).sort_by { |part| part.filename.to_s }
  end

  def audit_company_id
    company_id
  end
end
