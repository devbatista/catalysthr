# A daily pg_dump or a restore drill (spec 20, section 5, RN-20-041, RN-20-046, D-627). The
# error keeps only the failure's class and message: no data from the database.
class BackupRun < ApplicationRecord
  KINDS = %w[daily_dump restore_drill].freeze
  STATUSES = %w[running succeeded failed].freeze

  enum :kind, KINDS.index_by(&:itself), validate: true
  enum :status, STATUSES.index_by(&:itself), validate: true

  validates :started_at, presence: true

  scope :latest_first, -> { order(started_at: :desc) }

  def succeed!(**attributes)
    finish!("succeeded", **attributes)
  end

  def fail!(error)
    finish!("failed", error_message: "#{error.class}: #{error.message}".first(1_000))
  end

  private

  def finish!(status, **attributes)
    now = Time.current
    update!(status: status, finished_at: now, duration_seconds: (now - started_at).round, **attributes)
  end
end
