# One upload of a document (spec 08, RN-08-020, P-08-08): up to 5 images or one PDF, scanned
# for viruses before anything else (P-05-30), then joined in one PDF (RN-08-011) that the HR
# reviews. A platform type with an extraction profile is read by the AI before the review
# (spec 14, D-670); the others go straight to it. Approving it replaces the previous one, which
# only the HR still sees (RN-08-023, D-280).
class DocumentVersion < ApplicationRecord
  STATUSES = %w[submitted scanning ai_processing ai_failed awaiting_review approved correction_requested replaced
    rejected_by_scan].freeze
  # The reasons of a correction, shown to the employee (RN-08-022, P-08-09).
  CORRECTION_REASONS = %w[illegible expired wrong_type incomplete divergent other].freeze
  REVIEWABLE = %w[awaiting_review ai_failed].freeze

  acts_as_tenant :company

  audited

  belongs_to :document, inverse_of: :versions
  belongs_to :uploaded_by, class_name: "User"
  belongs_to :reviewed_by, class_name: "User", optional: true
  has_many_attached :files
  # The single PDF the HR reviews and the employee opens (RN-08-011).
  has_one_attached :pdf
  # What the AI read, for the review (spec 14, RN-14-020).
  has_one :ai_extraction, as: :subject, dependent: :destroy

  enum :status, STATUSES.index_by(&:itself), validate: true

  normalizes :correction_note, with: ->(text) { text.to_s.strip.presence }

  validates :number, numericality: { only_integer: true, greater_than: 0 }
  validates :correction_reason, inclusion: { in: CORRECTION_REASONS }, if: :correction_requested?
  validates :correction_note, presence: true, if: -> { correction_requested? && correction_reason == "other" }
  validates :correction_note, length: { maximum: 2000 }

  def audit_company_id
    company_id
  end

  def reviewable?
    status.in?(REVIEWABLE)
  end

  def scans
    files.blobs.map(&:file_scan)
  end

  # The PDF, once it exists and its scan is clean.
  def readable?
    pdf.attached? && pdf.blob.file_scan&.clean?
  end
end
