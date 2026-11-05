# The history of a process (RN-06-051, D-641): who did what, when and why, in the order it
# happened. Never changed afterwards. Only the HR sees it.
class ProcessEvent < ApplicationRecord
  ACTIONS = %w[started item_completed item_approved item_rejected item_forwarded item_skipped item_unblocked item_added
    item_removed item_updated item_moved responsible_changed client_changed due_recalculated completed cancelled
    document_submitted document_approved document_correction_requested item_acknowledged form_submitted form_returned
    form_applied].freeze

  acts_as_tenant :company

  belongs_to :instance, class_name: "ProcessInstance", foreign_key: :process_instance_id, inverse_of: :events
  belongs_to :item, class_name: "ProcessItem", foreign_key: :process_item_id, optional: true
  belongs_to :actor, class_name: "User", optional: true

  validates :action, inclusion: { in: ACTIONS }

  before_update { raise ActiveRecord::ReadOnlyRecord }
end
