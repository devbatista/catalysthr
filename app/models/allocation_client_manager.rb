# A client manager of an allocation client (RN-04-094, D-570): a person with the
# client_manager role in the company, which nobody holds with another role (P-02-38).
class AllocationClientManager < ApplicationRecord
  audited

  acts_as_tenant :company

  belongs_to :allocation_client
  belongs_to :membership

  validates :membership_id, uniqueness: { scope: :allocation_client_id }
  validate :client_manager_of_company

  def audit_company_id
    company_id
  end

  private

  def client_manager_of_company
    return if membership.nil?

    valid = membership.organization_type == "Company" && membership.organization_id == company_id &&
      membership.roles.include?("client_manager") && !membership.revoked?
    errors.add(:membership, :not_client_manager) unless valid
  end
end
