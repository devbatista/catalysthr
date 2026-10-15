# Changes to a person's access in an organization (spec 02, RN-02-060 to RN-02-063;
# spec 03, RN-03-012 and RN-03-013). Each one becomes an access event of kind admin
# (RN-05-020) and stays in the trail (RN-05-010).
module Memberships
  module_function

  # A direct company keeps at least one active HR administrator (RN-03-013, P-03-36).
  # A partner's company is served by the partner.
  def ensure_hr_admin_remains!(membership, removing:)
    company = membership.organization
    return unless removing && company.is_a?(Company) && company.direct?
    return if Membership.active.where(organization: company).where.not(id: membership.id)
      .where("'hr_admin' = ANY(roles)").exists?

    membership.errors.add(:base, :last_hr_admin)
    raise ActiveRecord::RecordInvalid, membership
  end
end
