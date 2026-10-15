module Memberships
  # Changes the roles, the released modules and, for a consultant, the assigned
  # companies (RN-03-012, D-191, D-052). Removing a role ends the sessions that relied
  # on it (RN-02-063, in Membership).
  class UpdateAccess
    def self.call(**)
      new(**).call
    end

    # company_ids is given only for the partner's team; nil leaves the assignments alone.
    def initialize(membership:, roles:, enabled_modules:, by:, company_ids: nil)
      @membership = membership
      @roles = Array(roles).compact_blank
      @enabled_modules = Array(enabled_modules).compact_blank
      @company_ids = company_ids
      @by = by
    end

    def call
      before = { roles: @membership.roles, enabled_modules: @membership.enabled_modules }
      Membership.transaction do
        Memberships.ensure_admin_remains!(@membership, keeping_roles: @roles)
        @membership.update!(roles: @roles,
          enabled_modules: (@roles & Membership::ROLES_WITH_MODULES).any? ? @enabled_modules : [])
      end
      record("roles_changed", before[:roles], @membership.roles)
      record("modules_changed", before[:enabled_modules], @membership.enabled_modules)
      AssignCompanies.call(membership: @membership, company_ids: @company_ids, by: @by) unless @company_ids.nil?
      @membership
    end

    private

    def record(action, from, to)
      return if from.sort == to.sort

      AccessEvent.record!(kind: "admin", action: action, user: @by, subject: @membership, metadata: { from: from, to: to })
    end
  end
end
