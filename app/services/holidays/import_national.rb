module Holidays
  # Brings a year's national holidays from BrasilAPI for the team's review (P-11-06,
  # D-638). A date already there, pending, published or rejected, is not proposed again,
  # so running twice changes nothing. Good Friday comes already marked as a holiday the HR
  # may turn off in a unit; the team confirms it when publishing. Returns the new ones.
  module ImportNational
    GOOD_FRIDAY = /sexta-feira (santa|da paixão)/i

    module_function

    def call(year)
      BrasilApi.national(year).filter_map do |entry|
        holiday = Holiday.level_national.create_with(name: entry.name, status: "pending", source: "brasil_api",
          unit_opt_out: entry.name.match?(GOOD_FRIDAY)).find_or_create_by!(date: entry.date)
        holiday if holiday.previously_new_record?
      end
    end
  end
end
