# A file sent to an import (spec 18, section 4.1, D-661, D-662): read and validated in the
# background, shown as a preview, recorded only after the HR confirms (D-462), with the result
# and its errors. The file stays 90 days (RN-18-010); afterwards only the counts and the
# messages, without the data.
class DataImport < ApplicationRecord
  STATUSES = %w[uploaded validating preview importing completed completed_with_errors failed cancelled undoing undone].freeze
  # A file is split above these (RN-18-002, P-18-01).
  MAX_SIZE = 20.megabytes
  MAX_ROWS = 10_000
  RETENTION = 90.days
  FINISHED = %w[completed completed_with_errors failed cancelled undone].freeze

  acts_as_tenant :company

  belongs_to :created_by, class_name: "User"
  belongs_to :undone_by, class_name: "User", optional: true
  has_many :rows, -> { order(:position) }, class_name: "DataImportRow", inverse_of: :data_import, dependent: :delete_all
  has_one_attached :file

  enum :status, STATUSES.index_by(&:itself), validate: true

  # What kept the last attempt from undoing it (RN-18-051, D-665): [{ "record", "message" }].
  # Encrypted: it names people.
  serialize :undo_blockers, coder: JSON
  # A mass update from the screen (RN-18-030, D-669): { "filters" => {...}, "changes" => {...} },
  # with no file. Encrypted, since the change may carry a salary (D-086).
  serialize :screen, coder: JSON
  encrypts :undo_blockers, :screen

  validates :kind, inclusion: { in: ->(_) { Imports::Kinds.codes } }
  validates :original_filename, presence: true, length: { maximum: 255 }

  def kind_class
    Imports::Kinds.fetch(kind)
  end

  def only_valid?
    options["only_valid"] == true
  end

  def finished?
    status.in?(FINISHED)
  end

  # Waiting for the background: the page refreshes itself meanwhile.
  def working?
    uploaded? || validating? || importing? || undoing?
  end

  def undo_blockers
    super || []
  end

  # Everything is imported only without errors; otherwise, only the valid lines (RN-18-001).
  def importable?
    preview? && valid_count.positive?
  end

  def all_valid?
    error_count.zero?
  end
end
