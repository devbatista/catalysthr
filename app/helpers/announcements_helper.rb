# The board's status and audience, in the panel and in the portal (spec 15, D-656).
module AnnouncementsHelper
  STATUS_PILLS = { "draft" => "pill-mute", "scheduled" => "pill-info", "published" => "pill-ok", "expired" => "pill-mute",
    "withdrawn" => "pill-bad" }.freeze

  def announcement_status_pill(announcement)
    key = announcement.status
    key = "waiting_scan" if announcement.scheduled? && announcement.publish_at <= Time.current
    key = "expired" if announcement.published? && !announcement.live?
    tone = key == "waiting_scan" ? "pill-warn" : STATUS_PILLS.fetch(key)
    tag.span(t("announcements.statuses.#{key}"), class: "pill #{tone}")
  end

  # "Todos", or each list chosen with its names. The names are read once per page.
  def announcement_audience_summary(audience)
    return t("announcements.audience.everyone") if audience.everyone?

    parts = audience.filter.map do |key, values|
      names = values.map { |value| announcement_audience_names.fetch(key).fetch(value, nil) }.compact.sort
      "#{t("announcements.audience.#{key}")}: #{names.join(", ")}"
    end
    safe_join(parts, " · ")
  end

  # The choices of the form; the HR analyst's units and their departments only (P-15-22).
  def announcement_audience_options(unit_ids)
    units = Unit.active.ordered
    departments = Department.active.includes(:unit).ordered
    unless unit_ids == :all
      units = units.where(id: unit_ids)
      departments = departments.where(unit_id: unit_ids)
    end
    {
      "unit_ids" => units.map { |unit| [ unit.name, unit.id ] },
      "department_ids" => departments.map { |department| [ "#{department.name} (#{department.unit.name})", department.id ] },
      "position_ids" => Position.active.ordered.map { |position| [ position.name, position.id ] },
      "employment_kinds" => Employment::KINDS.map { |kind| [ t("employments.kinds.#{kind}"), kind ] }
    }
  end

  def announcement_audience_names
    @announcement_audience_names ||= {
      "unit_ids" => Unit.pluck(:id, :name).to_h,
      "department_ids" => Department.pluck(:id, :name).to_h,
      "position_ids" => Position.pluck(:id, :name).to_h,
      "employment_kinds" => Employment::KINDS.index_with { |kind| t("employments.kinds.#{kind}") }
    }
  end

  # The date and time in the headquarters' time zone, as the form takes them.
  def announcement_time(time, zone)
    l(time.in_time_zone(zone), format: "%d/%m/%Y %H:%M")
  end
end
