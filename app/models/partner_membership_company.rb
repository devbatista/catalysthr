# A company assigned to a consultant of the partner (D-052). Only companies of the same
# partner can be assigned (RN-01-011).
class PartnerMembershipCompany < ApplicationRecord
  audited

  belongs_to :membership
  belongs_to :company

  validates :company_id, uniqueness: { scope: :membership_id }
  validate :same_partner

  private

  def same_partner
    return if membership.nil? || company.nil?

    errors.add(:company, :other_partner) unless membership.organization_type == "Partner" &&
      membership.organization_id == company.partner_id
  end
end
