# A file of a batch (RN-08-061, RN-08-062): its type and person, suggested by the AI and by
# the system (RN-14-030, RN-14-031, D-672) and chosen by the HR, and whether it waits, is
# confirmed, discarded or already in a folder. Only a clean file is distributed (P-05-30).
# The suggestions keep no person's data: the type, the AI's confidence in it, how the person
# was found and the candidates' ids with their scores.
class DocumentBatchItem < ApplicationRecord
  STATUSES = %w[pending confirmed discarded distributed].freeze

  acts_as_tenant :company

  audited

  belongs_to :batch, class_name: "DocumentBatch", foreign_key: :document_batch_id, inverse_of: :items
  belongs_to :suggested_type, class_name: "DocumentType", optional: true
  belongs_to :suggested_worker_profile, class_name: "WorkerProfile", optional: true
  belongs_to :confirmed_type, class_name: "DocumentType", optional: true
  belongs_to :confirmed_worker_profile, class_name: "WorkerProfile", optional: true
  belongs_to :document, optional: true
  has_one_attached :file
  has_one :ai_extraction, as: :subject, dependent: :destroy

  enum :status, STATUSES.index_by(&:itself), validate: true

  PERSON_MATCHES = %w[cpf name none].freeze

  validates :person_match, inclusion: { in: PERSON_MATCHES }, allow_nil: true
  validates :type_confidence, inclusion: { in: Ai::Prompts::DocumentExtraction::CONFIDENCES }, allow_nil: true

  validates :confirmed_type, :confirmed_worker_profile, presence: true, if: :confirmed?

  def audit_company_id
    company_id
  end

  def scan_status
    file.blob&.file_scan&.status || "scanning"
  end

  def clean?
    scan_status == "clean"
  end

  def infected?
    scan_status == "infected"
  end
end
