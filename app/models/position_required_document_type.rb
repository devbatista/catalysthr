# A document a position requires (RN-04-030, D-204): it enters the admission's process even
# when the model doesn't have it (RN-06-037, P-06-13, D-648).
class PositionRequiredDocumentType < ApplicationRecord
  audited

  acts_as_tenant :company

  belongs_to :position
  belongs_to :document_type

  validates :document_type_id, uniqueness: { scope: :position_id }

  def audit_company_id
    company_id
  end
end
