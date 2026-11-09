# The imports' screens (spec 18, D-661).
module DataImportsHelper
  STATUS_PILLS = { "uploaded" => "pill-info", "validating" => "pill-info", "importing" => "pill-info", "preview" => "pill-warn",
    "completed" => "pill-ok", "completed_with_errors" => "pill-warn", "failed" => "pill-bad", "cancelled" => "pill-mute",
    "undoing" => "pill-info", "undone" => "pill-mute" }.freeze

  def data_import_status_pill(import)
    tag.span(t("imports.statuses.#{import.status}"), class: "pill #{STATUS_PILLS.fetch(import.status)}")
  end

  def data_import_kind_title(code)
    t("imports.kinds.#{code}.title")
  end

  # A value of the line as the page shows it: a sensitive column's masked (D-086, D-663). The
  # values in full are only in the file of errors, after the password (RN-18-041).
  def data_import_value(sheets, row, column, value)
    return if value.blank?

    sensitive = sheets[row.sheet]&.column(column)&.sensitive
    sensitive ? SensitiveData.mask(value, as: sensitive) : value
  end

  # The column's header in the sheet, for an error or a change.
  def data_import_column(sheets, row, column)
    sheets[row.sheet]&.column(column)&.header || column
  end
end
