module Processes
  # Turns an item's role into the memberships that answer for it when the process starts
  # (RN-06-020, D-234, P-06-05). A role with nobody goes to the process's HR, with an
  # alert (RN-06-022, P-06-06). Read inside the company.
  class Responsibles
    Assignment = Data.define(:membership_ids, :fallback)

    # starter: the membership of who starts the process, in the company or, for the
    # partner's consultant, in the partner.
    def initialize(company:, employment:, kind:, starter:)
      @company = company
      @employment = employment
      @kind = kind
      @starter = starter
      @revision = employment.effective_revision
    end

    def for(role)
      ids = ids_for(role).uniq
      ids.any? ? Assignment.new(membership_ids: ids, fallback: false) : Assignment.new(membership_ids: hr_ids, fallback: true)
    end

    # The process's HR: who started it, when of the HR of the person's unit; otherwise that
    # HR (D-641).
    def hr_ids
      @hr_ids ||= begin
        unit_hr = HrScope.new(@company).memberships_for(unit_id: @revision&.unit_id, kind: @kind).map(&:id)
        unit_hr.include?(@starter&.id) ? [ @starter.id ] : unit_hr
      end
    end

    private

    def ids_for(role)
      case role
      when "employee" then [ @employment.worker_profile.membership_id ]
      when "hr" then hr_ids
      when "manager" then active_ids(department&.managers)
      when "upper_manager" then active_ids(department&.managers_above)
      when "accountant" then accountant_ids
      when "client_manager" then active_ids(client&.managers)
      when "initiator" then [ @starter&.id ].compact
      else []
      end
    end

    def department
      @revision&.department_id && Department.find_by(id: @revision.department_id)
    end

    def client
      @revision&.allocation_client_id && AllocationClient.find_by(id: @revision.allocation_client_id)
    end

    def active_ids(memberships)
      Array(memberships).select { |membership| membership.status.in?(Membership::ACCESS_STATUSES) }.map(&:id)
    end

    # The accounting firm linked to the company (D-171).
    def accountant_ids
      link = AccountingFirmCompany.find_by(company: @company, status: "active")
      return [] unless link

      Membership.with_access.where(organization: link.accounting_firm).pluck(:id)
    end
  end
end
