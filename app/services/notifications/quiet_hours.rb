module Notifications
  # The fixed quiet hours of the push (RN-15-030, RN-15-031, P-15-10): from 20h to 8h,
  # weekends and the unit's holidays, in the unit's time zone. By the work schedule
  # (RN-15-032) comes with spec 11, in phase 3 (D-654); until then nobody has one, and the
  # fixed rule applies, as D-403 says.
  module QuietHours
    OPENS = 8
    CLOSES = 20

    module_function

    # When a notice held now can leave, or nil when it can leave at once.
    def release_at(membership, now: Time.current)
      PersonPlace.with(membership) do |zone, calendar|
        local = now.in_time_zone(zone)
        date = local.to_date
        next if calendar.business_day?(date) && local.hour >= OPENS && local.hour < CLOSES

        date += 1 unless calendar.business_day?(date) && local.hour < OPENS
        date += 1 until calendar.business_day?(date)
        zone.local(date.year, date.month, date.day, OPENS)
      end
    end
  end
end
