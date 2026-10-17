# A company moved between partners, or to and from the direct modality, with the
# company's authorization (RN-01-050, D-123, D-599). The company's data stay as they
# are; only the owner of its subdomain changes (RN-01-051).
class CompanyTransfer < ApplicationRecord
  DOCUMENT_TYPES = %w[application/pdf image/png image/jpeg image/webp].freeze
  MAX_DOCUMENT_SIZE = 10.megabytes

  belongs_to :company
  belongs_to :from_partner, class_name: "Partner", optional: true
  belongs_to :to_partner, class_name: "Partner", optional: true
  belongs_to :performed_by, class_name: "User"
  has_one_attached :authorization_document

  validates :authorized_by_text, presence: true, length: { maximum: 2000 }
  validates :performed_at, presence: true

  def to_direct?
    to_partner_id.nil?
  end
end
