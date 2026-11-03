# One person of a document request (RN-08-041): the pending document of the folder that
# answers it, followed until the HR approves a version of it.
class DocumentRequestTarget < ApplicationRecord
  STATUSES = %w[pending in_review fulfilled].freeze

  acts_as_tenant :company

  belongs_to :request, class_name: "DocumentRequest", foreign_key: :document_request_id, inverse_of: :targets
  belongs_to :worker_profile
  belongs_to :document

  enum :status, STATUSES.index_by(&:itself), validate: true

  # Still without an approved document after the date, where the person works.
  def late?(due_on)
    pending? && due_on.present? && due_on < worker_profile.today
  end

  # Follows the document's latest version (RN-08-041).
  def self.status_for(version)
    case version&.status
    when "approved" then "fulfilled"
    when "scanning", "submitted", "ai_processing", "ai_failed", "awaiting_review" then "in_review"
    else "pending"
    end
  end
end
