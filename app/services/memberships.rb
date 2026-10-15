# Changes to a person's access in an organization (spec 02, RN-02-060 to RN-02-063;
# spec 03, RN-03-012 and RN-03-013). Each one becomes an access event of kind admin
# (RN-05-020) and stays in the trail (RN-05-010).
module Memberships
  # The administrator role each organization keeps (RN-03-013, D-584).
  ADMIN_ROLES = { "Company" => "hr_admin", "Partner" => "partner_admin", "AccountingFirm" => "firm_admin" }.freeze

  module_function

  # The last active administrator is neither removed nor demoted: a direct company keeps
  # an HR administrator (RN-03-013, P-03-36), and a partner or an accounting firm keeps
  # its administrator (D-584). A partner's company is served by the partner. The
  # organization's row is locked, so two administrators removing each other at the same
  # time cannot both pass. Call it inside a transaction.
  def ensure_admin_remains!(membership, keeping_roles:)
    organization = membership.organization
    role = ADMIN_ROLES.fetch(membership.organization_type)
    return unless membership.active? && membership.roles.include?(role) && !keeping_roles.include?(role)
    return if organization.is_a?(Company) && !organization.direct?

    organization.lock!
    return if Membership.active.where(organization: organization).where.not(id: membership.id).with_role(role).exists?

    membership.errors.add(:base, :"last_#{role}")
    raise ActiveRecord::RecordInvalid, membership
  end
end
