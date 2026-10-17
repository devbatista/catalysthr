# A unit assigned to an HR analyst: the U scope (spec 03, D-142). The HR administrator
# assigns them (spec 03, section 4.2).
class MembershipUnit < ApplicationRecord
  audited

  acts_as_tenant :company

  belongs_to :membership
  belongs_to :unit

  validates :unit_id, uniqueness: { scope: :membership_id }
  validate :same_company

  def audit_company_id
    company_id
  end

  private

  def same_company
    return if membership.nil? || unit.nil?

    errors.add(:unit, :other_company) unless membership.organization_type == "Company" &&
      membership.organization_id == company_id && unit.company_id == company_id
  end
end
