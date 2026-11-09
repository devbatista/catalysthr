require "csv"

module Imports
  # Reads an import's file (RN-18-003, P-18-02): XLSX with roo, CSV with Ruby's library, comma
  # or semicolon and UTF-8 or Windows-1252, detected. Columns are found by the header's name,
  # not by the position; the first line is the header. Empty lines are skipped, and a file
  # above 10,000 lines is refused (RN-18-002). Returns the lines by sheet.
  class Reader
    class Error < StandardError
      attr_reader :key, :details

      def initialize(key, **details)
        @key = key
        @details = details
        super(key.to_s)
      end
    end

    def initialize(kind, io, filename)
      @kind = kind
      @io = io
      @filename = filename.to_s
    end

    def read
      tables = xlsx? ? xlsx_tables : csv_tables
      lines = @kind.sheets.to_h { |sheet| [ sheet.key, lines_of(sheet, tables[sheet.key]) ] }
      raise Error.new(:empty) if lines.values.all?(&:empty?)
      raise Error.new(:too_many_rows, max: DataImport::MAX_ROWS) if lines.values.sum(&:size) > DataImport::MAX_ROWS

      lines
    end

    def self.format_of(filename)
      File.extname(filename.to_s).delete(".").downcase.presence_in(%w[xlsx csv])
    end

    private

    def xlsx?
      self.class.format_of(@filename) == "xlsx"
    end

    # Each sheet of the kind, by its tab's title.
    def xlsx_tables
      book = Roo::Excelx.new(@io.path, file_warning: :ignore)
      titles = book.sheets.index_by { |title| Normalize.key(title) }
      @kind.sheets.to_h do |sheet|
        title = titles[Normalize.key(sheet.title)]
        rows = title ? book.sheet(title).each_row_streaming(pad_cells: true).map { |cells| cells.map { |cell| cell&.value } } : nil
        [ sheet.key, rows ]
      end
    rescue Zip::Error, Roo::Error, ArgumentError, Nokogiri::SyntaxError => error
      raise Error.new(:unreadable, reason: error.class.name)
    end

    # A CSV is a single sheet: the kind must have only one.
    def csv_tables
      raise Error.new(:xlsx_only) if @kind.sheets.size > 1 || !@kind.formats.include?("csv")

      text = @io.read.to_s
      text = text.delete_prefix("\xEF\xBB\xBF".b)
      text = text.dup.force_encoding(Encoding::UTF_8)
      text = text.encode(Encoding::UTF_8, Encoding::Windows_1252) unless text.valid_encoding?
      separator = text.lines.first.to_s.count(";") >= text.lines.first.to_s.count(",") ? ";" : ","
      { @kind.sheets.first.key => CSV.parse(text, col_sep: separator) }
    rescue CSV::MalformedCSVError, EncodingError => error
      raise Error.new(:unreadable, reason: error.class.name)
    end

    def lines_of(sheet, rows)
      return [] if rows.nil? || rows.empty?

      header, *data = rows
      columns = header.map { |title| column_for(sheet, title) }
      missing = sheet.columns.select(&:required) - columns
      raise Error.new(:missing_columns, sheet: sheet.title, columns: missing.map(&:header).to_sentence) if missing.any?

      data.each_with_index.filter_map do |cells, index|
        values = columns.each_with_index.filter_map { |column, at| [ column.key, column.read(Normalize.text(cells[at])) ] if column }.to_h.compact
        Line.new(sheet.key, index + 2, values) if values.any?
      end
    end

    def column_for(sheet, title)
      wanted = Normalize.key(title.to_s.delete("*"))
      sheet.columns.find { |column| Normalize.key(column.header) == wanted }
    end
  end
end
