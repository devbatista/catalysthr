# A document the HR asks for, from one person or a group (spec 08, RN-08-040, RN-08-041,
# D-278, D-643): each person gets a pending document in the folder, answered once the HR
# approves it. The panel counts the answered, in review, pending and late ones.
class DocumentRequest < ApplicationRecord
  acts_as_tenant :company

  audited

  belongs_to :document_type
  belongs_to :requested_by, class_name: "User"
  has_many :targets, class_name: "DocumentRequestTarget", inverse_of: :request, dependent: nil

  normalizes :message, with: ->(text) { text.to_s.strip.presence }

  validates :message, length: { maximum: 2000 }

  def audit_company_id
    company_id
  end

  # { "fulfilled" => 6, "in_review" => 2, "pending" => 4, "late" => 1 } (CA-08-005). A late
  # one is also pending.
  def counts(targets = self.targets.to_a)
    counts = Hash.new(0).merge(targets.map(&:status).tally)
    counts["late"] = targets.count { |target| target.late?(due_on) }
    counts
  end
end
