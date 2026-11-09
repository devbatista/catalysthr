module Imports
  # The file sent, back with a column "Erros" (RN-18-006, P-18-04): every line, so the HR fixes
  # the ones with errors and sends the whole file again. Built from the lines kept encrypted;
  # after the 90 days there is nothing to build it from (RN-18-010).
  class ErrorsFile
    def initialize(import)
      @import = import
    end

    def available?
      @import.purged_at.nil? && @import.rows.any?
    end

    def filename
      "#{I18n.t("imports.kinds.#{@import.kind}.file")}-erros-#{@import.created_at.to_date.iso8601}.xlsx"
    end

    def to_xlsx
      package = Axlsx::Package.new
      book = package.workbook
      error_style = book.styles.add_style(fg_color: "9E3422", b: true, alignment: { wrap_text: true })
      header_style = book.styles.add_style(b: true, bg_color: "E6ECF2")
      rows = @import.rows.to_a.group_by(&:sheet)
      @import.kind_class.sheets.each do |sheet|
        lines = rows.fetch(sheet.key.to_s, [])
        next if lines.empty?

        book.add_worksheet(name: sheet.title) do |tab|
          headers = sheet.columns.map(&:header) + [ I18n.t("imports.errors_file.column") ]
          tab.add_row(headers, style: header_style)
          lines.each do |row|
            values = sheet.columns.map { |column| row.payload[column.key] }
            errors = row.issues.map { |issue| issue["message"] }.join(" · ")
            tab.add_row(values + [ errors.presence ], types: Array.new(headers.size, :string),
              style: Array.new(sheet.columns.size) + [ error_style ])
          end
          tab.column_widths(*Array.new(sheet.columns.size, 18), 60)
        end
      end
      package.to_stream.read
    end
  end
end
