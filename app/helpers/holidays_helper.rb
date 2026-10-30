# Holidays on the admin's and the unit's screens (RN-06-029, RN-11-020, D-638).
module HolidaysHelper
  # The date with the weekday, as "15/11/2027 (seg)".
  def holiday_date(date)
    l(date, format: :with_weekday)
  end

  # Where the holiday counts: national, the state's or the city's.
  def holiday_place(holiday)
    case holiday.level
    when "national" then t("holidays.levels.national")
    when "state" then t("holidays.levels.state_of", state: holiday.state)
    else t("holidays.levels.city_of", city: holiday.city_name, state: holiday.state)
    end
  end
end
