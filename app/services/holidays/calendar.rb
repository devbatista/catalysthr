module Holidays
  # A unit's days off, for deadlines in calendar or business days (RN-06-025, RN-06-026,
  # D-235, D-236): business days leave out weekends, the published national holidays, the
  # state's and the city's, and the unit's own, less a national holiday the HR turned off
  # in the unit (D-638). An optional day is a normal day (RN-11-022). Without a unit, only
  # the national holidays count. Read inside the unit's company.
  class Calendar
    Entry = Data.define(:date, :name, :origin, :kind, :holiday, :unit_holiday, :opted_out)

    def initialize(unit = nil)
      @unit = unit
      @days_off = {}
    end

    def holiday?(date)
      days_off(date.year).include?(date)
    end

    def business_day?(date)
      !date.saturday? && !date.sunday? && !holiday?(date)
    end

    # The date N days after (positive) or before (negative) another. In business days,
    # each step skips the days off; the reference date itself is not counted.
    def shift(date, days, business:)
      return date + days unless business

      step = days.negative? ? -1 : 1
      remaining = days.abs
      while remaining.positive?
        date += step
        remaining -= 1 if business_day?(date)
      end
      date
    end

    # The year's days for the unit's screen: the holidays that reach it, the ones turned
    # off in it, and its own holidays and optional days.
    def entries(year)
      platform, own = load(year)
      opt_outs = own.select(&:opt_out?).index_by(&:holiday_id)
      platform_entries = platform.map do |holiday|
        opt_out = opt_outs[holiday.id] if holiday.unit_opt_out
        Entry.new(date: holiday.date, name: holiday.name, origin: holiday.level, kind: "holiday", holiday: holiday,
          unit_holiday: opt_out, opted_out: opt_out.present?)
      end
      own_entries = own.reject(&:opt_out?).map do |day|
        Entry.new(date: day.date, name: day.name, origin: "unit", kind: day.kind, holiday: nil, unit_holiday: day, opted_out: false)
      end
      (platform_entries + own_entries).sort_by { |entry| [ entry.date, Holiday::LEVELS.index(entry.origin) || Holiday::LEVELS.size ] }
    end

    private

    def days_off(year)
      @days_off[year] ||= entries(year).filter_map { |entry| entry.date if entry.kind == "holiday" && !entry.opted_out }.to_set
    end

    def load(year)
      platform = Holiday.published.in_year(year).reaching(state: @unit&.state, ibge_city_code: @unit&.ibge_city_code).ordered.to_a
      own = @unit ? UnitHoliday.where(unit: @unit).where(date: Date.new(year).all_year).to_a : []
      [ platform, own ]
    end
  end
end
