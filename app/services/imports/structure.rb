module Imports
  # The structure's import (spec 18, kind 1, P-18-08, D-662): units, departments with their
  # parent and positions with the CBO, in one XLSX with three tabs validated together, so a
  # department points to a unit or a parent of the same file (RN-18-005). The code is the key:
  # an existing code updates, a new one creates, and empty cells never erase (RN-18-007). The
  # rules are the manual ones: the models validate, and a department never changes unit.
  class Structure
    CODE = "structure".freeze
    MODELS = { units: Unit, departments: Department, positions: Position }.freeze
    # The model's attribute behind each column, for its errors and its changes.
    ATTRIBUTES = {
      units: { "code" => :code, "name" => :name, "registration_type" => :registration_type, "registration_number" => :registration_number,
        "postal_code" => :postal_code, "street" => :street, "street_number" => :street_number, "complement" => :complement,
        "district" => :district, "city" => :city, "state" => :state, "time_zone" => :time_zone },
      departments: { "code" => :code, "name" => :name, "unit_code" => :unit, "parent_code" => :parent },
      positions: { "code" => :code, "name" => :name, "cbo_code" => :cbo_code, "salary_min" => :salary_min_cents,
        "salary_max" => :salary_max_cents, "description" => :description, "requirements" => :requirements }
    }.freeze
    UNIT_FIELDS = %w[name registration_number postal_code street street_number complement district city state time_zone].freeze

    class ApplyError < StandardError; end

    Entry = Struct.new(:line, :record, :issues)

    def self.code = CODE
    def self.formats = %w[xlsx]

    # Only the HR administrator, and the support in the assisted import (RN-18-042, D-661).
    def self.allowed?(ability) = ability.can?(:import, :structure)

    def self.sheets
      t = ->(key) { I18n.t("imports.structure.columns.#{key}") }
      hint = ->(key) { I18n.t("imports.structure.hints.#{key}") }
      [
        Sheet.new(:units, I18n.t("imports.structure.sheets.units"), [
          Column.new(key: "code", header: t.("code"), required: true, hint: hint.("code")),
          Column.new(key: "name", header: t.("unit_name"), required: true),
          Column.new(key: "registration_type", header: t.("registration_type"),
            options: -> { Unit::REGISTRATION_TYPES.map { |type| [ I18n.t("units.registration_types.#{type}"), type ] } }),
          Column.new(key: "registration_number", header: t.("registration_number")),
          Column.new(key: "postal_code", header: t.("postal_code"), digits: 8),
          Column.new(key: "street", header: t.("street")),
          Column.new(key: "street_number", header: t.("street_number")),
          Column.new(key: "complement", header: t.("complement")),
          Column.new(key: "district", header: t.("district")),
          Column.new(key: "city", header: t.("city")),
          Column.new(key: "state", header: t.("state"), options: -> { Unit::STATES.map { |state| [ state, state ] } }),
          Column.new(key: "time_zone", header: t.("time_zone"), hint: hint.("time_zone"),
            options: -> { Unit::TIME_ZONES.map { |zone| [ zone, zone ] } })
        ]),
        Sheet.new(:departments, I18n.t("imports.structure.sheets.departments"), [
          Column.new(key: "code", header: t.("code"), required: true, hint: hint.("code")),
          Column.new(key: "name", header: t.("department_name"), required: true),
          Column.new(key: "unit_code", header: t.("unit_code"), required: true, hint: hint.("unit_code")),
          Column.new(key: "parent_code", header: t.("parent_code"), hint: hint.("parent_code"))
        ]),
        Sheet.new(:positions, I18n.t("imports.structure.sheets.positions"), [
          Column.new(key: "code", header: t.("code"), required: true, hint: hint.("code")),
          Column.new(key: "name", header: t.("position_name"), required: true),
          Column.new(key: "cbo_code", header: t.("cbo_code"), required: true, digits: 6, hint: hint.("cbo_code")),
          Column.new(key: "salary_min", header: t.("salary_min"), hint: hint.("amount")),
          Column.new(key: "salary_max", header: t.("salary_max"), hint: hint.("amount")),
          Column.new(key: "description", header: t.("description")),
          Column.new(key: "requirements", header: t.("requirements"))
        ])
      ]
    end

    # The order to record: units, then each department after its parent, then positions.
    def self.order(rows)
      units, departments, positions = %w[units departments positions].map { |sheet| rows.select { |row| row.sheet == sheet } }
      by_code = departments.index_by { |row| key(row.payload["code"]) }
      sorted = []
      visit = lambda do |row, path|
        return if sorted.include?(row) || path.include?(row)

        parent = by_code[key(row.payload["parent_code"])]
        visit.call(parent, path + [ row ]) if parent
        sorted << row
      end
      departments.each { |row| visit.call(row, []) }
      units + sorted + positions
    end

    def self.key(code) = code.to_s.strip.upcase.presence

    def initialize(import)
      @import = import
      @sheets = self.class.sheets.index_by(&:key)
    end

    # The preview of every line (RN-18-005, RN-18-006): nothing is recorded.
    def validate(lines)
      units = entries(:units, lines[:units])
      units.each { |entry| assign_unit(entry) }
      units.each { |entry| check_model(:units, entry) }

      departments = entries(:departments, lines[:departments])
      file_units = valid_by_code(units)
      invalid_units = units.reject { |entry| entry.issues.empty? }.index_by { |entry| self.class.key(entry.line.values["code"]) }
      departments.each { |entry| assign_department_unit(entry, file_units, invalid_units) }
      by_code = departments.select(&:record).index_by { |entry| entry.record.code }
      departments.each { |entry| assign_department_parent(entry, by_code) }
      cycles(departments).each { |entry| entry.issues << issue(:departments, "parent_code", entry.line, :cycle) }
      departments.each { |entry| check_model(:departments, entry) }

      positions = entries(:positions, lines[:positions])
      positions.each { |entry| assign_position(entry) }
      positions.each { |entry| check_model(:positions, entry) }

      { units: units, departments: departments, positions: positions }.flat_map do |sheet, sheet_entries|
        sheet_entries.map { |entry| result_for(sheet, entry) }
      end
    end

    # Records a confirmed valid line (RN-18-008): the references now come from what the earlier
    # lines recorded. Returns the record and the action, or raises with the errors.
    def apply(sheet, values)
      sheet = sheet.to_sym
      entry = entries(sheet, [ Line.new(sheet, 0, values) ]).first
      case sheet
      when :units then assign_unit(entry)
      when :departments
        assign_department_unit(entry, {}, {})
        assign_department_parent(entry, {})
      when :positions then assign_position(entry)
      end
      check_model(sheet, entry)
      raise ApplyError, entry.issues.map { |each| each["message"] }.to_sentence if entry.issues.any?

      record = entry.record
      action = record.new_record? ? "create" : (record.changed? ? "update" : "none")
      record.save! unless action == "none"
      [ record, action ]
    end

    private

    # Each line with its record found by the code, or new; a blank or repeated code is an error.
    def entries(sheet, lines)
      seen = {}
      Array(lines).map do |line|
        code = self.class.key(line.values["code"])
        if code.nil?
          Entry.new(line, nil, [ issue(sheet, "code", line, :blank) ])
        elsif seen[code]
          Entry.new(line, nil, [ issue(sheet, "code", line, :repeated, line: seen[code]) ])
        else
          seen[code] = line.number
          model = MODELS.fetch(sheet)
          Entry.new(line, model.with_code(code).first || model.new(code: code), [])
        end
      end
    end

    def valid_by_code(entries)
      entries.select { |entry| entry.record && entry.issues.empty? }.index_by { |entry| entry.record.code }
    end

    def assign_unit(entry)
      return unless entry.record

      values = entry.line.values
      type = Normalize.option(values["registration_type"], @sheets[:units].column("registration_type").options.call)
      if type == :invalid
        entry.issues << issue(:units, "registration_type", entry.line, :not_in_list)
      elsif type
        entry.record.registration_type = type
      end
      entry.record.assign_attributes(values.slice(*UNIT_FIELDS).compact)
    end

    def assign_department_unit(entry, file_units, invalid_units)
      return unless entry.record

      code = self.class.key(entry.line.values["unit_code"])
      unit = Unit.with_code(code).first || file_units[code]&.record
      if unit.nil?
        key = invalid_units[code] ? :unit_invalid : :unit_missing
        entry.issues << issue(:departments, "unit_code", entry.line, key, code: code, line: invalid_units[code]&.line&.number)
      elsif entry.record.persisted? && entry.record.unit_id != unit.id
        entry.issues << issue(:departments, "unit_code", entry.line, :unit_changes)
      else
        entry.record.unit = unit
      end
      entry.record.name = entry.line.values["name"] if entry.line.values["name"]
    end

    # The parent: recorded already, or another line of the file. Both must be in the same
    # unit (RN-04-020); a line with errors is an error here too.
    def assign_department_parent(entry, by_code)
      code = self.class.key(entry.line.values["parent_code"])
      return unless entry.record && code

      parent_entry = by_code[code]
      parent = Department.with_code(code).first
      if parent_entry && parent_entry != entry && parent_entry.issues.any?
        entry.issues << issue(:departments, "parent_code", entry.line, :parent_invalid, code: code, line: parent_entry.line.number)
      elsif parent_entry || parent
        parent_unit = parent_entry ? self.class.key(parent_entry.line.values["unit_code"]) : parent.unit.code
        own_unit = self.class.key(entry.line.values["unit_code"])
        if parent_unit != own_unit
          entry.issues << issue(:departments, "parent_code", entry.line, :other_unit)
        else
          entry.record.parent = parent_entry ? parent_entry.record : parent
        end
      else
        entry.issues << issue(:departments, "parent_code", entry.line, :parent_missing, code: code)
      end
    end

    def assign_position(entry)
      return unless entry.record

      values = entry.line.values
      record = entry.record
      record.name = values["name"] if values["name"]
      record.cbo_code = values["cbo_code"] if values["cbo_code"]
      { "salary_min" => :salary_min_cents, "salary_max" => :salary_max_cents }.each do |column, attribute|
        cents = Normalize.cents(values[column])
        if cents == :invalid
          entry.issues << issue(:positions, column, entry.line, :invalid_amount)
        elsif cents
          record[attribute] = cents
        end
      end
      record.description = values["description"] if values["description"]
      record.requirements = values["requirements"] if values["requirements"]
    end

    # Departments of the file whose parents go round back to them.
    def cycles(entries)
      parents = entries.select(&:record).to_h { |entry| [ entry.record.code, self.class.key(entry.line.values["parent_code"]) ] }
      entries.select do |entry|
        next false unless entry.record

        node = parents[entry.record.code]
        visited = []
        found = false
        while node && parents.key?(node) && visited.exclude?(node)
          found = true and break if node == entry.record.code

          visited << node
          node = parents[node]
        end
        found
      end
    end

    # The manual rules (RN-18-005), once the line has no error of its own.
    def check_model(sheet, entry)
      return if entry.record.nil? || entry.issues.any? || entry.record.valid?

      columns = ATTRIBUTES.fetch(sheet).invert
      entry.record.errors.each do |error|
        column = columns[error.attribute] || columns[error.attribute.to_s.delete_suffix("_id").to_sym]
        entry.issues << { "column" => column, "value" => column && entry.line.values[column], "message" => error.full_message }
      end
    end

    def result_for(sheet, entry)
      return Result.for(entry.line, issues: entry.issues) if entry.issues.any? || entry.record.nil?
      return Result.for(entry.line, action: "create") if entry.record.new_record?
      return Result.for(entry.line, action: "update", diff: diff(sheet, entry.record)) if entry.record.changed?

      Result.for(entry.line)
    end

    # The fields that change, before and after, by column (RN-18-007).
    def diff(sheet, record)
      columns = ATTRIBUTES.fetch(sheet).invert
      record.changes.filter_map do |attribute, (before, after)|
        column = columns[attribute.to_sym] || columns[attribute.delete_suffix("_id").to_sym]
        [ column, [ display(sheet, attribute, before), display(sheet, attribute, after) ] ] if column
      end.to_h
    end

    def display(sheet, attribute, value)
      return if value.nil?
      return Department.find_by(id: value)&.name || value.to_s if attribute == "parent_id"
      return I18n.t("units.registration_types.#{value}") if sheet == :units && attribute == "registration_type"

      value.to_s
    end

    def issue(sheet, column, line, key, **details)
      header = @sheets.fetch(sheet).column(column).header
      { "column" => column, "value" => line.values[column],
        "message" => I18n.t("imports.errors.#{key}", column: header, value: line.values[column], **details) }
    end
  end
end
