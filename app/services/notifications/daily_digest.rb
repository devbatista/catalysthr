module Notifications
  # When the e-mail of a notice waits for the daily digest (RN-15-040 to RN-15-042, D-655):
  # 7h30 of the next day from Monday to Friday, in the person's unit (D-654). Holding the
  # delivery until then is what makes Monday's digest bring the weekend and what lets each
  # time zone leave at its own hour. Without the flag, the e-mails go one by one (D-607).
  module DailyDigest
    HOUR = 7
    MINUTE = 30

    module_function

    def send_at(notification, now: Time.current)
      membership = notification.recipient_membership
      return unless membership && notification.type.digest_for?(membership.roles)
      return unless FeatureFlags.enabled?(FeatureFlags::NOTIFICATION_DIGEST)

      PersonPlace.with(membership) do |zone, _calendar|
        local = now.in_time_zone(zone)
        date = local.to_date
        date += 1 unless local < zone.local(date.year, date.month, date.day, HOUR, MINUTE)
        date += 1 while date.saturday? || date.sunday?
        zone.local(date.year, date.month, date.day, HOUR, MINUTE)
      end
    end
  end
end
