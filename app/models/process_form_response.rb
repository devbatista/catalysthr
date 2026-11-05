# The answers of a form item (RN-06-030, RN-06-031, D-649), saved as a draft on the server
# (the portal keeps nothing on the device) and encrypted as a whole. It has no version on
# purpose: sensitive answers never reach PaperTrail (D-086). Once applied, only the free
# fields stay, which live only in the process, with the names of what went to the record.
class ProcessFormResponse < ApplicationRecord
  acts_as_tenant :company

  belongs_to :item, class_name: "ProcessItem", foreign_key: :process_item_id, inverse_of: :form_response
  belongs_to :submitted_by, class_name: "User", optional: true
  belongs_to :applied_by, class_name: "User", optional: true

  serialize :answers, coder: JSON
  encrypts :answers

  def data
    answers || {}
  end

  def applied?
    applied_at.present?
  end

  # Wipes what isn't needed anymore: a skipped item, a cancelled process (D-649).
  def self.discard(items)
    where(process_item_id: items, applied_at: nil).find_each { |response| response.update!(answers: nil) }
  end
end
