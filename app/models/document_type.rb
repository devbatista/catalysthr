# A document type as the company sees it (spec 08, D-270): its own types and, read only,
# the platform's, which the company may turn off and whose notice it may change (P-08-04).
# The team keeps the platform's as PlatformDocumentType, in the same table.
class DocumentType < ApplicationRecord
  include DocumentTypeDefinition

  acts_as_tenant :company, has_global_records: true

  has_many :settings, class_name: "CompanyDocumentTypeSetting", dependent: nil
  has_many :position_expirations, class_name: "PositionDocumentExpiration", dependent: nil

  validate :company_only, on: :create

  def audit_company_id
    company_id
  end

  # The company's own types and the platform's it did not turn off, the ones a new
  # document may take (RN-08-004).
  def self.usable
    disabled = CompanyDocumentTypeSetting.where(enabled: false).select(:document_type_id)
    active.where.not(id: disabled)
  end

  def setting
    return if company_id

    @setting ||= settings.find_by(company: ActsAsTenant.current_tenant)
  end

  def enabled?
    active? && setting&.enabled != false
  end

  # The notice's advance, the company's when it changed the platform's (RN-08-031, D-275).
  def effective_alert_days
    setting&.alert_days || alert_days
  end

  # The months of a periodicity type, by position when the company set one (D-272).
  def months_for(position)
    return expiration_months unless position

    position_expirations.find_by(position: position)&.expiration_months || expiration_months
  end

  private

  def company_only
    errors.add(:base, :platform_owned) if company_id.nil?
  end
end
