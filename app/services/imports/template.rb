module Imports
  # The XLSX template of a kind (RN-18-001, step 1, D-464): a tab of instructions with each
  # column, whether it is required and its options, then a tab per sheet with the headers, the
  # required ones highlighted, and the lists as drop-downs that warn but do not block, kept in
  # a hidden tab. A code or a CEP that the spreadsheet turns into a number keeps its zeros when
  # read (Column#read).
  class Template
    def initialize(kind)
      @kind = kind
    end

    def filename
      "#{I18n.t("imports.kinds.#{@kind.code}.file")}-modelo.xlsx"
    end

    def to_xlsx
      package = Axlsx::Package.new
      package.use_shared_strings = true
      book = package.workbook
      styles = styles(book)
      lists = option_lists
      instructions(book, styles)
      @kind.sheets.each { |sheet| data_tab(book, sheet, styles, lists) }
      lists_tab(book, lists) if lists.any?
      package.to_stream.read
    end

    private

    # Every column with options, in order, with its place in the hidden tab.
    def option_lists
      @kind.sheets.flat_map { |sheet| sheet.columns.select(&:options).map { |column| [ sheet, column ] } }
        .each_with_index.map { |(sheet, column), index| { sheet: sheet.key, column: column.key, letter: Axlsx.col_ref(index),
          labels: column.options.call.map(&:first) } }
    end

    def lists_name = I18n.t("imports.template.lists")

    def data_tab(book, sheet, styles, lists)
      book.add_worksheet(name: sheet.title) do |tab|
        tab.add_row(sheet.columns.map(&:header), style: sheet.columns.map { |column| column.required ? styles[:required] : styles[:header] },
          types: Array.new(sheet.columns.size, :string))
        sheet.columns.each_with_index do |column, index|
          list = lists.find { |each| each[:sheet] == sheet.key && each[:column] == column.key }
          next unless list

          letter = Axlsx.col_ref(index)
          tab.add_data_validation("#{letter}2:#{letter}#{DataImport::MAX_ROWS + 1}",
            type: :list, formula1: "'#{lists_name}'!$#{list[:letter]}$1:$#{list[:letter]}$#{list[:labels].size}",
            hideDropDown: false, showErrorMessage: true, errorStyle: :warning,
            errorTitle: I18n.t("imports.template.list_title"), error: I18n.t("imports.template.list_error"))
        end
        tab.column_widths(*sheet.columns.map { |column| [ column.header.size + 6, 18 ].max })
      end
    end

    def lists_tab(book, lists)
      book.add_worksheet(name: lists_name, state: :hidden) do |tab|
        lists.map { |list| list[:labels].size }.max.times do |row|
          tab.add_row(lists.map { |list| list[:labels][row] }, types: Array.new(lists.size, :string))
        end
      end
    end

    def styles(book)
      style = book.styles
      {
        header: style.add_style(b: true, bg_color: "E6ECF2", fg_color: "0A2A4A"),
        required: style.add_style(b: true, bg_color: "085087", fg_color: "FFFFFF"),
        title: style.add_style(b: true, sz: 14, fg_color: "0A2A4A"),
        bold: style.add_style(b: true),
        wrap: style.add_style(alignment: { wrap_text: true, vertical: :top })
      }
    end

    # What each column is (RN-18-001): one table per tab.
    def instructions(book, styles)
      book.add_worksheet(name: I18n.t("imports.template.instructions")) do |tab|
        tab.add_row([ I18n.t("imports.kinds.#{@kind.code}.title") ], style: styles[:title])
        I18n.t("imports.template.intro").each { |text| tab.add_row([ text ], style: styles[:wrap]) }
        @kind.sheets.each do |sheet|
          tab.add_row([])
          tab.add_row([ I18n.t("imports.template.tab", tab: sheet.title) ], style: styles[:bold])
          tab.add_row(I18n.t("imports.template.columns"), style: styles[:bold])
          sheet.columns.each do |column|
            options = column.options&.call&.map(&:first)
            options = options.size > 20 ? I18n.t("imports.template.see_list") : options.join(", ") if options
            tab.add_row([ column.header, I18n.t(column.required ? "imports.template.required" : "imports.template.optional"),
              [ column.hint, options ].compact.join(" ") ], style: [ nil, nil, styles[:wrap] ])
          end
        end
        tab.column_widths(34, 14, 90)
      end
    end
  end
end
