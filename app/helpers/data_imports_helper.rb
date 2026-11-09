# The imports' screens (spec 18, D-661).
module DataImportsHelper
  STATUS_PILLS = { "uploaded" => "pill-info", "validating" => "pill-info", "importing" => "pill-info", "preview" => "pill-warn",
    "completed" => "pill-ok", "completed_with_errors" => "pill-warn", "failed" => "pill-bad", "cancelled" => "pill-mute",
    "undone" => "pill-mute" }.freeze

  def data_import_status_pill(import)
    tag.span(t("imports.statuses.#{import.status}"), class: "pill #{STATUS_PILLS.fetch(import.status)}")
  end

  def data_import_kind_title(code)
    t("imports.kinds.#{code}.title")
  end

  # The column's header in the sheet, for an error or a change.
  def data_import_column(sheets, row, column)
    sheets[row.sheet]&.column(column)&.header || column
  end
end
