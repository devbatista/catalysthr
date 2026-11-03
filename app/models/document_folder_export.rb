# A person's folder in ZIP, for who asked it (spec 08, RN-08-082, D-281, P-08-21, D-644):
# made in a job with the versions in force that this person may read, served by the
# application only to them, for 24 hours, without a password (D-642).
class DocumentFolderExport < ApplicationRecord
  STATUSES = %w[queued ready failed expired].freeze
  LIFETIME = 24.hours

  acts_as_tenant :company

  belongs_to :worker_profile
  belongs_to :requested_by, class_name: "User"
  has_one_attached :zip

  enum :status, STATUSES.index_by(&:itself), validate: true

  def available?
    ready? && expires_at&.future? && zip.attached?
  end
end
