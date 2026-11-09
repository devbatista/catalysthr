module Imports
  # The salary and position history (spec 18, kind 6, P-18-08, D-207, D-664): each line is a
  # revision of an employment, by the CPF, the registration number and the date, with the
  # reason. The manual rules hold (RN-04-060 to RN-04-064, RN-18-005).
  #
  # A cell left empty keeps the condition in force the day before, so a raise brings only the
  # salary. A line on the date of a revision that exists with other conditions becomes a
  # "Correção" on that date, which prevails (D-603): the employments of block 18b start with
  # today's conditions, and the history fixes them without changing a revision in force. The
  # same conditions on the same date change nothing, so sending the file again is harmless.
  class EmploymentHistory < PersonKind
    CODE = "employment_history".freeze
    # The conditions of a revision, by column, and what a new one inherits.
    CONDITIONS = {
      "position_code" => :position, "unit_code" => :unit, "department_code" => :department, "salary" => :salary_cents,
      "salary_unit" => :salary_unit, "variable_salary_description" => :variable_salary_description,
      "weekly_hours" => :weekly_hours
    }.freeze
    # The revision's attribute each column writes.
    ATTRIBUTES = {
      "position_code" => :position_id, "unit_code" => :unit_id, "department_code" => :department_id, "salary" => :salary_cents,
      "salary_unit" => :salary_unit, "variable_salary_description" => :variable_salary_description,
      "weekly_hours" => :weekly_hours
    }.freeze
    INHERITED = %i[position_id unit_id department_id allocation_client_id salary_cents salary_unit variable_salary_description
      weekly_hours].freeze
    TYPES = { "cpf" => :cpf, "effective_on" => :date, "reason" => :option, "salary" => :cents, "salary_unit" => :option,
      "weekly_hours" => :decimal }.freeze
    # Where each error of the revision shows in the sheet.
    MODEL_COLUMNS = { position: "position_code", unit: "unit_code", department: "department_code", salary_cents: "salary",
      employment: "registration_number" }.freeze

    def self.code = CODE

    def self.sheets
      column = ->(key, **options) { Column.new(key: key, header: label(key), hint: hint(key), **options) }
      [
        Sheet.new(:revisions, I18n.t("imports.employment_history.sheet"), [
          column.("cpf", required: true, digits: 11),
          column.("registration_number", required: true),
          column.("effective_on", required: true),
          column.("reason", required: true,
            options: -> { EmploymentRevision::CHANGE_REASONS.map { |reason| [ I18n.t("employment_revisions.reasons.#{reason}"), reason ] } }),
          column.("position_code", options: -> { Employees.codes(Position) }),
          column.("unit_code", options: -> { Employees.codes(Unit) }),
          column.("department_code", options: -> { Employees.codes(Department) }),
          column.("salary", sensitive: :money),
          column.("salary_unit", options: -> { EmploymentRevision::SALARY_UNITS.map { |unit| [ I18n.t("employment_revisions.salary_units.#{unit}"), unit ] } }),
          column.("variable_salary_description"),
          column.("weekly_hours"),
          column.("justification")
        ])
      ]
    end

    # Each employment's lines from the oldest date, so a line inherits from the one before it.
    def self.order(rows)
      rows.sort_by do |row|
        date = Normalize.date(row.payload["effective_on"])
        [ row.payload["registration_number"].to_s.strip, date.is_a?(Date) ? date : Date.new(9999), row.line_number ]
      end
    end

    # A note above the preview: the past revisions are retroactive (RN-04-062).
    def self.preview_note = I18n.t("imports.employment_history.retroactive_note")

    # The preview records each employment's lines in date order, as the confirmation will, and
    # undoes everything: the same rules, nothing stays (D-462).
    def validate(lines)
      lines = Array(lines[sheet_key])
      parsed = lines.map { |line| read(line) }
      repeated(parsed)
      results = {}
      ActiveRecord::Base.transaction(requires_new: true) do
        parsed.select { |each| each.issues.empty? }
          .sort_by { |each| [ each["registration_number"], each["effective_on"], each.line.number ] }
          .each { |each| results[each.line.number] = simulate(each) }
        raise ActiveRecord::Rollback
      end
      parsed.map { |each| results[each.line.number] || result(each.line, issues: each.issues) }
    end

    def apply(_sheet, values)
      parsed = read(Line.new(sheet_key, 0, values))
      apply_error!(parsed.issues) if parsed.issues.any?

      revision, action, issues = record(parsed)
      apply_error!(issues) if issues.any?
      [ revision, action ]
    end

    private

    def read(line)
      parsed = parse(line, TYPES)
      parsed.values["registration_number"] = parsed["registration_number"]&.strip
      resolve_codes(parsed)
      employment = find_employment(parsed["registration_number"]) if parsed["registration_number"]
      if employment.nil?
        parsed.issues << issue("registration_number", line, :employment_missing) if parsed["registration_number"]
      elsif parsed["cpf"] && employment.worker_profile.user.cpf != parsed["cpf"]
        parsed.issues << issue("registration_number", line, :registration_taken)
      else
        parsed.values["employment"] = employment
      end
      parsed
    end

    def find_employment(number)
      (@employments ||= {}).fetch(number) do
        @employments[number] = Employment.includes(worker_profile: { membership: :user }).find_by(registration_number: number)
      end
    end

    # The same employment and date twice in the file.
    def repeated(parsed)
      seen = {}
      parsed.each do |each|
        key = [ each["registration_number"], each["effective_on"] ]
        next unless key.all?

        each.issues << issue("effective_on", each.line, :repeated_revision, line: seen[key]) if seen[key]
        seen[key] ||= each.line.number
      end
    end

    def simulate(parsed)
      _, action, issues, diff = record(parsed)
      result(parsed.line, issues: issues, action: action, diff: diff || {})
    rescue ActiveRecord::ActiveRecordError => error
      result(parsed.line, issues: [ { "column" => nil, "value" => nil, "message" => I18n.t("imports.errors.unexpected", kind: error.class.name) } ])
    end

    # Records the line's revision, in a savepoint. Returns the revision, the action, the errors
    # and, for a correction, what changes on that date.
    def record(parsed)
      employment = parsed["employment"]
      date = parsed["effective_on"]
      revisions = employment.revisions.reload.to_a
      same_date = revisions.select { |revision| revision.effective_on == date }.max_by(&:id)
      base = same_date || revisions.select { |revision| revision.effective_on < date }.max_by { |revision| [ revision.effective_on, revision.id ] }
      revision = employment.revisions.new(base&.slice(*INHERITED) || {})
      ATTRIBUTES.each { |column, attribute| revision[attribute] = value(parsed[column]) if parsed.given?(column) }
      revision.assign_attributes(effective_on: date, reason: parsed["reason"], justification: parsed["justification"], created_by: @by)

      if same_date
        changes = changed(same_date, revision)
        return [ same_date, "none", [], {} ] if changes.empty?

        revision.reason = "correction"
        diff = changes.merge("reason" => [ reason_label(same_date.reason), reason_label("correction") ])
      end

      issues = []
      ActiveRecord::Base.transaction(requires_new: true) do
        unless revision.save
          issues = model_issues(revision, parsed.line, MODEL_COLUMNS)
          raise ActiveRecord::Rollback
        end
      end
      [ revision, same_date ? "update" : "create", issues, diff ]
    end

    def reason_label(reason) = I18n.t("employment_revisions.reasons.#{reason}")

    def value(given)
      given.is_a?(ApplicationRecord) ? given.id : given
    end

    # The conditions that differ from the revision of the same date, before and after.
    def changed(current, revision)
      CONDITIONS.each_with_object({}) do |(column, attribute), changes|
        before = current.public_send(attribute)
        after = revision.public_send(attribute)
        same = before.is_a?(Numeric) && after.is_a?(Numeric) ? before.to_d == after.to_d : before == after
        changes[column] = [ shown(column, before), shown(column, after) ] unless same
      end
    end

    def shown(column, value)
      return value.code || value.name if value.is_a?(ApplicationRecord)

      display(column, value)
    end
  end
end
