module Imports
  # What the kinds about people share (spec 18, kinds 2 to 4, D-663): one sheet, XLSX or CSV,
  # only the HR administrator (D-661), the password confirmation to send, confirm and download
  # the errors (RN-18-041), and reading each cell as the manual form does (RN-18-004,
  # RN-18-005). A subclass gives the columns, validates the lines and records one.
  class PersonKind
    # A line read: its values already as the models take them, and its errors.
    Parsed = Struct.new(:line, :values, :issues) do
      def [](key) = values[key]
      def given?(key) = values.key?(key)
    end

    def self.formats = %w[xlsx csv]
    def self.sensitive? = true
    def self.allowed?(ability) = ability.can?(:import, code.to_sym)

    def self.column(key) = sheets.first.column(key)

    def self.label(key) = I18n.t("imports.#{code}.columns.#{key}")
    def self.hint(key) = I18n.t("imports.#{code}.hints.#{key}", default: nil)

    def self.yes_no
      -> { [ [ I18n.t("imports.yes"), "true" ], [ I18n.t("imports.no"), "false" ] ] }
    end

    def initialize(import)
      @import = import
      @company = import.company
      @by = import.created_by
    end

    private

    def sheet = self.class.sheets.first
    def sheet_key = sheet.key

    # The line's values cast by the kind's own types: dates, amounts, numbers, Sim or Não and
    # the lists' options. A value that does not read becomes the line's error.
    def parse(line, types)
      parsed = Parsed.new(line, {}, [])
      sheet.columns.each do |column|
        raw = line.values[column.key]
        if raw.blank?
          parsed.issues << issue(column.key, line, :blank) if column.required
          next
        end

        value = cast(column, raw, types[column.key])
        if value.is_a?(Symbol) && value.to_s.start_with?("invalid")
          parsed.issues << issue(column.key, line, value)
        else
          parsed.values[column.key] = value
        end
      end
      parsed
    end

    def cast(column, raw, type)
      case type
      when :date then Normalize.date(raw).then { |date| date == :invalid ? :invalid_date : date }
      when :cents then Normalize.cents(raw).then { |cents| cents == :invalid ? :invalid_amount : cents }
      when :decimal then Normalize.decimal(raw).then { |number| number == :invalid ? :invalid_number : number }
      when :boolean then Normalize.boolean(raw).then { |flag| flag == :invalid ? :invalid_boolean : flag }
      when :cpf then Cpf.valid?(raw.to_s) ? Cpf.normalize(raw) : :invalid_cpf
      when :option then Normalize.option(raw, column.options.call).then { |code| code == :invalid ? :invalid_option : code }
      else raw
      end
    end

    # The structure's records by the code (D-662), loaded once per import.
    CODED = { "position_code" => "Position", "unit_code" => "Unit", "department_code" => "Department" }.freeze

    # The codes of the line replaced by their records; a code that does not exist is an error.
    def resolve_codes(parsed)
      CODED.each do |column, model|
        code = parsed[column].to_s.strip.upcase.presence
        next unless code

        record = coded(model)[code]
        record ? parsed.values[column] = record : parsed.issues << issue(column, parsed.line, :code_missing, code: code)
      end
    end

    def coded(model)
      (@coded ||= {})[model] ||= model.constantize.where.not(code: nil).index_by(&:code)
    end

    # The model's errors by the column they belong to; the others without a column.
    def model_issues(record, line, columns = {})
      record.errors.map do |error|
        column = columns.fetch(error.attribute) { error.attribute.to_s if sheet.column(error.attribute.to_s) }
        { "column" => column, "value" => column && line.values[column], "message" => error.full_message }
      end
    end

    def issue(column, line, key, **details)
      header = sheet.column(column)&.header
      message = I18n.t("imports.errors.#{key}", column: header, **details)
      { "column" => column, "value" => column && line.values[column], "message" => message }
    end

    # The fields that change, before and after, by column (RN-18-007).
    def diff(record, columns)
      record.changes.filter_map do |attribute, (before, after)|
        column = columns[attribute]
        [ column, [ display(column, before), display(column, after) ] ] if column
      end.to_h
    end

    # A list's value as its label; the rest as text.
    def display(column, value)
      return if value.nil?

      options = sheet.column(column)&.options
      return options.call.find { |_, code| code == value.to_s }&.first || value.to_s if options
      return I18n.l(value, format: "%d/%m/%Y") if value.is_a?(Date)

      value.to_s
    end

    def result(line, issues: [], action: "none", diff: {})
      Result.for(line, issues: issues, action: issues.any? ? "none" : action, diff: issues.any? ? {} : diff)
    end

    def apply_error!(issues)
      raise ApplyError, issues.map { |each| each["message"] }.uniq.to_sentence
    end
  end
end
