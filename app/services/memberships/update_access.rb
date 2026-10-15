module Memberships
  # Changes the roles and the released modules (RN-03-012, D-191). Removing a role ends
  # the sessions that relied on it (RN-02-063, in Membership).
  class UpdateAccess
    def self.call(**)
      new(**).call
    end

    def initialize(membership:, roles:, enabled_modules:, by:)
      @membership = membership
      @roles = Array(roles).compact_blank
      @enabled_modules = Array(enabled_modules).compact_blank
      @by = by
    end

    def call
      before = { roles: @membership.roles, enabled_modules: @membership.enabled_modules }
      Memberships.ensure_hr_admin_remains!(@membership,
        removing: @membership.roles.include?("hr_admin") && !@roles.include?("hr_admin"))

      @membership.update!(roles: @roles, enabled_modules: (@roles & Membership::ROLES_WITH_MODULES).any? ? @enabled_modules : [])
      record("roles_changed", before[:roles], @membership.roles)
      record("modules_changed", before[:enabled_modules], @membership.enabled_modules)
      @membership
    end

    private

    def record(action, from, to)
      return if from.sort == to.sort

      AccessEvent.record!(kind: "admin", action: action, user: @by, subject: @membership, metadata: { from: from, to: to })
    end
  end
end
