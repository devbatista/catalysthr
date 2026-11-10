# The company's full export (spec 18, D-667).
module CompanyExportsHelper
  STATUS_PILLS = { "queued" => "pill-info", "generating" => "pill-info", "ready" => "pill-ok", "expired" => "pill-mute",
    "failed" => "pill-bad" }.freeze

  def company_export_status_pill(export)
    tag.span(t("exports.statuses.#{export.status}"), class: "pill #{STATUS_PILLS.fetch(export.status)}")
  end
end
