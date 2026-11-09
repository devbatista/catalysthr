module Notifications
  # Where a person is, for the quiet hours and the daily digest (RN-15-031, RN-15-041,
  # D-654): the unit of the current employment; without one, the headquarters of the
  # person's company; without a company (partner, accounting firm, the team), Brasília's
  # time zone and the national holidays only.
  module PersonPlace
    BRASILIA = "America/Sao_Paulo"

    module_function

    # Yields the time zone and the calendar, inside the company: the calendar reads the
    # unit's own days as it goes.
    def with(membership)
      company = membership&.organization
      return yield(ActiveSupport::TimeZone[BRASILIA], Holidays::Calendar.new) unless company.is_a?(Company)

      ActsAsTenant.with_tenant(company) do
        unit = WorkerProfile.find_by(membership: membership)&.current_unit || company.headquarters
        yield(ActiveSupport::TimeZone[unit.time_zone], Holidays::Calendar.new(unit))
      end
    end
  end
end
