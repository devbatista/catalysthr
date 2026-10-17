# A manager of a department: a membership of the company, active, with the manager role
# (RN-04-021, P-04-09, D-203). Any of the department's managers may approve (RN-04-023).
class DepartmentManager < ApplicationRecord
  audited

  acts_as_tenant :company

  belongs_to :department
  belongs_to :membership

  validates :membership_id, uniqueness: { scope: :department_id }
  validate :active_manager_of_the_company

  def audit_company_id
    company_id
  end

  private

  def active_manager_of_the_company
    return if membership.nil?

    valid = membership.organization_type == "Company" && membership.organization_id == company_id &&
      membership.active? && membership.roles.include?("manager")
    errors.add(:membership, :not_manager) unless valid
  end
end
