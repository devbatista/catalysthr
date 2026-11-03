# The months of a periodicity type for one position, such as the periodic ASO every 6
# months in a risky position (D-272, RN-08-030).
class PositionDocumentExpiration < ApplicationRecord
  acts_as_tenant :company

  audited

  belongs_to :position
  belongs_to :document_type

  validates :expiration_months, numericality: { only_integer: true, in: 1..120 }
  validates :document_type_id, uniqueness: { scope: :position_id }
  validate :periodicity_type

  def audit_company_id
    company_id
  end

  private

  def periodicity_type
    errors.add(:document_type, :invalid) unless document_type&.expires_by_periodicity?
  end
end
