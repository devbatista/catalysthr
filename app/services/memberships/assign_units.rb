module Memberships
  # The units an HR analyst works on: the U scope (spec 03, D-142). Only the company's
  # active units count, and without the HR analyst role there are none. The HR
  # administrator assigns them (spec 03, section 4.2).
  class AssignUnits
    def self.call(**)
      new(**).call
    end

    def initialize(membership:, unit_ids:, by:)
      @membership = membership
      @unit_ids = Array(unit_ids).compact_blank
      @by = by
    end

    def call
      ActsAsTenant.with_tenant(@membership.organization) { assign }
      @membership
    end

    private

    def assign
      wanted = @membership.roles.include?("hr_analyst") ? Unit.active.where(id: @unit_ids).pluck(:id) : []
      current = MembershipUnit.where(membership: @membership).pluck(:unit_id)
      return if wanted.sort == current.sort

      MembershipUnit.transaction do
        MembershipUnit.where(membership: @membership, unit_id: current - wanted).destroy_all
        (wanted - current).each { |unit_id| MembershipUnit.create!(membership: @membership, unit_id: unit_id) }
      end
      AccessEvent.record!(kind: "admin", action: "units_assigned", user: @by, subject: @membership,
        metadata: { from: current.sort, to: wanted.sort })
    end
  end
end
