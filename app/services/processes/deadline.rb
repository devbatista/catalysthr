module Processes
  # An item's date: N days before or after one of the process's dates, in calendar or
  # business days of the person's unit (RN-06-025, RN-06-026, CA-06-003). Without the
  # date yet, no deadline.
  module Deadline
    module_function

    def for(instance, anchor, offset_days, business)
      date = anchor && instance.anchor_date(anchor)
      date && instance.calendar.shift(date, offset_days.to_i, business: business)
    end
  end
end
