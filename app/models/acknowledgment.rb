# A person's acknowledgment of a document (spec 08, RN-08-050 to RN-08-054, D-279): it
# confirms the receipt, not agreement nor a signature (D-147, P-08-13). The employee
# confirms it in the portal (spec 16), with the date, time, IP, browser and the file's
# hash; without it by the date, the HR may record the refusal, with a note and up to two
# witnesses, whose CPFs are encrypted and stay out of the trail (D-086).
class Acknowledgment < ApplicationRecord
  STATUSES = %w[awaiting acknowledged refused].freeze
  MAX_WITNESSES = 2

  acts_as_tenant :company

  audited sensitive: %i[witnesses]

  belongs_to :publication, class_name: "DocumentPublication", foreign_key: :document_publication_id, optional: true,
    inverse_of: :acknowledgments
  belongs_to :document
  belongs_to :version, class_name: "DocumentVersion", foreign_key: :document_version_id
  belongs_to :worker_profile
  belongs_to :recorded_by, class_name: "User", optional: true

  serialize :witnesses, coder: JSON
  encrypts :witnesses

  enum :status, STATUSES.index_by(&:itself), validate: true

  normalizes :comment, with: ->(text) { text.to_s.strip.presence }
  normalizes :refused_note, with: ->(text) { text.to_s.strip.presence }

  validates :comment, length: { maximum: 2000 }
  validates :refused_note, presence: true, length: { maximum: 2000 }, if: :refused?

  def audit_company_id
    company_id
  end

  def witnesses
    super || []
  end

  # Past its date without the confirmation, where the person works (RN-08-053).
  def overdue?
    awaiting? && due_on < worker_profile.today
  end
end
