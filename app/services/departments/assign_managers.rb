module Departments
  # The department's managers: memberships of the company, active, with the manager role
  # (RN-04-021, P-04-09). Anything else in the list is refused by the record's validation.
  class AssignManagers
    def self.call(**)
      new(**).call
    end

    def initialize(department:, membership_ids:)
      @department = department
      @membership_ids = Array(membership_ids).compact_blank.map(&:to_i)
    end

    def call
      current = @department.department_managers.pluck(:membership_id)
      @department.department_managers.where(membership_id: current - @membership_ids).destroy_all
      (@membership_ids - current).each do |membership_id|
        @department.department_managers.create!(membership: Membership.find_by(id: membership_id))
      end
      @department
    end
  end
end
