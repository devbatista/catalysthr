# An item of a process waiting for another of the same process (RN-06-040, D-237).
class ProcessItemDependency < ApplicationRecord
  acts_as_tenant :company

  belongs_to :item, class_name: "ProcessItem", inverse_of: :dependencies
  belongs_to :depends_on_item, class_name: "ProcessItem", inverse_of: :dependents

  validate :same_process

  private

  def same_process
    errors.add(:depends_on_item, :invalid) if item && depends_on_item && item.process_instance_id != depends_on_item.process_instance_id
  end
end
