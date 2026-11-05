# A contract or term generated for an employment (RN-07-041 to RN-07-043, D-650): one per
# employment and model, because generating again replaces the PDF not yet signed. It stays
# in the process, out of the folder; only the signed one goes there.
class GeneratedDocument < ApplicationRecord
  STATUSES = %w[generating ready failed].freeze

  acts_as_tenant :company

  audited

  belongs_to :employment
  belongs_to :document_template
  belongs_to :generated_by, class_name: "User"
  belongs_to :signed_document, class_name: "Document", optional: true
  has_one_attached :file

  enum :status, STATUSES.index_by(&:itself), validate: true

  def audit_company_id
    company_id
  end

  # A signed document removed from the folder frees the model again.
  def signed?
    signed_document.present? && signed_document.deleted_at.nil?
  end
end
