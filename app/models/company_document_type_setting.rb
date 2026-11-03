# What a company changes on a platform's document type: turning it off, without touching
# the documents it already has (RN-08-004, P-08-04), and the notice's advance (D-275).
class CompanyDocumentTypeSetting < ApplicationRecord
  acts_as_tenant :company

  audited

  belongs_to :document_type

  validates :document_type_id, uniqueness: { scope: :company_id }
  validates :alert_days, numericality: { only_integer: true, in: 1..DocumentTypeDefinition::MAX_ALERT_DAYS }, allow_nil: true
  validate :platform_type

  def audit_company_id
    company_id
  end

  private

  def platform_type
    errors.add(:document_type, :invalid) unless document_type&.platform?
  end
end
