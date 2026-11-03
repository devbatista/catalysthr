# A document type of the platform, kept by the CatalystHR team for every company (spec 08,
# RN-08-001, D-270). The extraction by the AI comes with spec 14 (D-642). It reads only
# the rows without a company, so it never reaches a company's types.
class PlatformDocumentType < ApplicationRecord
  include DocumentTypeDefinition

  default_scope { where(company_id: nil) }

  normalizes :code, with: ->(code) { code.to_s.strip.downcase.presence }

  validates :code, presence: true, format: { with: /\A[a-z0-9_]+\z/ }, length: { maximum: 60 },
    uniqueness: { conditions: -> { where(company_id: nil) } }
  validate :no_company

  private

  def no_company
    errors.add(:base, :company_owned) if company_id.present?
  end
end
