# A PDF the HR publishes to one person or a group asking for their acknowledgment (spec 08,
# RN-08-050, D-279, D-643), such as a warning or a notice: each person gets the document in
# the folder, already approved, with the same file, and an acknowledgment waiting until the
# date.
class DocumentPublication < ApplicationRecord
  acts_as_tenant :company

  audited

  belongs_to :document_type
  belongs_to :published_by, class_name: "User"
  has_many :acknowledgments, inverse_of: :publication, dependent: nil

  normalizes :title, with: ->(title) { title.to_s.squish.presence }
  normalizes :message, with: ->(text) { text.to_s.strip.presence }

  validates :title, presence: true, length: { maximum: 160 }
  validates :message, length: { maximum: 2000 }
  validates :due_on, presence: true

  def audit_company_id
    company_id
  end
end
