module Imports
  # Mass updates (spec 18, section 4.2, P-18-14, D-668, D-669): each line is a revision of an
  # open employment, with the date and the reason (D-207), by the registration number or, when
  # the person has only one open employment, by the CPF. A new salary or a percentage over the
  # one in force on the date, rounded to the nearest cent with the half up (D-669); the
  # position, the unit, the department and the weekly hours. The manager is the department's
  # (D-664). A past date is retroactive (RN-04-062).
  #
  # As the history (EmploymentHistory): an empty cell keeps the condition in force the day
  # before, and the same conditions on the same date change nothing, so sending the file
  # again is harmless. Other conditions on the date of a revision make a new one with the
  # line's reason, which prevails (RN-04-061). Also from the screen that filters the people
  # (RN-18-030): the lines come from the filter, with the same preview and confirmation.
  #
  # The HR analyst updates only the employments of their units, and moves them only to their
  # units (RN-18-040, CA-18-005); the salary only with the payroll module (P-03-16, D-669).
  class MassUpdates < EmploymentHistory
    CODE = "mass_updates".freeze
    TYPES = EmploymentHistory::TYPES.merge("percent" => :decimal).freeze
    # The records the screen chooses by id: they may have no code.
    SCREEN_RECORDS = { "position_id" => [ "position_code", Position ], "unit_id" => [ "unit_code", Unit ],
      "department_id" => [ "department_code", Department ] }.freeze
    SCREEN_FILTERS = %w[unit_id department_id position_id].freeze
    SCREEN_CHANGES = %w[effective_on reason salary percent position_id unit_id department_id weekly_hours justification].freeze

    def self.code = CODE
    def self.allowed?(ability) = ability.can?(:import, :mass_updates)

    def self.sheets
      column = ->(key, **options) { Column.new(key: key, header: label(key), hint: hint(key), **options) }
      [
        Sheet.new(:mass_updates, I18n.t("imports.mass_updates.sheet"), [
          column.("cpf", digits: 11),
          column.("registration_number"),
          column.("effective_on", required: true),
          column.("reason", required: true,
            options: -> { EmploymentRevision::CHANGE_REASONS.map { |reason| [ I18n.t("employment_revisions.reasons.#{reason}"), reason ] } }),
          column.("salary", sensitive: :money),
          column.("percent"),
          column.("position_code", options: -> { Employees.codes(Position) }),
          column.("unit_code", options: -> { Employees.codes(Unit) }),
          column.("department_code", options: -> { Employees.codes(Department) }),
          column.("weekly_hours"),
          column.("justification")
        ])
      ]
    end

    def self.order(rows)
      rows.sort_by do |row|
        date = Normalize.date(row.payload["effective_on"])
        key = row.payload["registration_number"].to_s.strip.presence || People.cpf(row.payload["cpf"]).to_s
        [ key, date.is_a?(Date) ? date : Date.new(9999), row.line_number ]
      end
    end

    def self.preview_note = I18n.t("imports.mass_updates.preview_note")

    # The lines of an update from the screen (RN-18-030): one per open employment the filter
    # finds in the person's scope, all with the same change.
    def self.screen_lines(import, ability)
      screen = import.screen
      filters = screen.fetch("filters", {}).slice(*SCREEN_FILTERS).compact_blank
      changes = screen.fetch("changes", {}).slice(*SCREEN_CHANGES).compact_blank
      employments = Employment.open.where(id: EmploymentRevision.counting.where(filters).select(:employment_id))
        .includes(worker_profile: { membership: :user }).order(:registration_number).to_a
        .select { |employment| ability.can?(:update, employment.worker_profile) }
      lines = employments.each_with_index.map do |employment, index|
        Line.new(:mass_updates, index + 1, changes.merge("registration_number" => employment.registration_number))
      end
      { mass_updates: lines }
    end

    private

    def read(line)
      parsed = parse(line, TYPES)
      parsed.values["registration_number"] = parsed["registration_number"]&.strip
      screen_records(parsed, line)
      resolve_codes(parsed)
      employment = target(parsed, line)
      if employment
        parsed.values["employment"] = employment
        parsed.values["registration_number"] = employment.registration_number
        check_scope(parsed, employment, line)
      end
      if parsed.given?("salary") && parsed.given?("percent")
        parsed.issues << issue("percent", line, :salary_and_percent)
      end
      parsed
    end

    # The screen's choices come by id (RN-18-030).
    def screen_records(parsed, line)
      SCREEN_RECORDS.each do |key, (column, model)|
        next if line.values[key].blank?

        record = model.find_by(id: line.values[key])
        record ? parsed.values[column] = record : parsed.issues << issue(column, line, :code_missing, code: line.values[key])
      end
    end

    # By the registration number, or by the CPF of whom has a single open employment (D-669).
    def target(parsed, line)
      number = parsed["registration_number"]
      cpf = parsed["cpf"]
      if number.nil? && cpf.nil?
        parsed.issues << issue("registration_number", line, :key_missing) unless parsed.issues.any? { |each| each["column"] == "cpf" }
        return
      end

      employment = number ? find_employment(number) : open_employments(cpf, line, parsed)
      return if parsed.issues.any? { |each| each["column"].in?(%w[cpf registration_number]) }

      if employment.nil?
        parsed.issues << issue("registration_number", line, :employment_missing)
      elsif cpf && employment.worker_profile.user.cpf != cpf
        parsed.issues << issue("registration_number", line, :registration_taken)
      elsif !employment.open?
        parsed.issues << issue("registration_number", line, :employment_closed)
      else
        employment
      end
    end

    def open_employments(cpf, line, parsed)
      profile = People.profiles_by_cpf([ cpf ])[cpf]
      employments = profile ? profile.employments.select(&:open?) : []
      if employments.size > 1
        parsed.issues << issue("cpf", line, :registration_needed)
        return
      end
      employments.first
    end

    # The HR analyst's units, now and where the line moves to (RN-18-040, CA-18-005), and the
    # salary only with the payroll module (P-03-16, D-669). The support's assisted import
    # works on the whole company (RN-18-060).
    def check_scope(parsed, employment, line)
      return if @import.assisted?

      profile = employment.worker_profile
      parsed.issues << issue("registration_number", line, :update_out_of_scope) unless ability.can?(:update, profile)
      unit = parsed["unit_code"]
      parsed.issues << issue("unit_code", line, :update_out_of_scope) if unit.is_a?(Unit) && !ability.can?(:revise_in, unit)
      if (parsed.given?("salary") || parsed.given?("percent")) && !ability.can?(:read_pay, profile)
        parsed.issues << issue(parsed.given?("salary") ? "salary" : "percent", line, :no_pay_permission)
      end
    end

    def ability
      @ability ||= Ability.new(@by, area: :panel, company: @company)
    end

    # The percentage over the salary in force on the date, to the nearest cent, half up
    # (D-669); a unit changed without a department of the new unit is an error (RN-04-064).
    def adjust(parsed, revision, base)
      issues = []
      if parsed.given?("percent")
        if base&.salary_cents.nil?
          issues << issue("percent", parsed.line, :no_salary_for_percent)
        else
          revision.salary_cents = (BigDecimal(base.salary_cents) * (100 + parsed["percent"]) / 100).round(0, BigDecimal::ROUND_HALF_UP).to_i
        end
      end
      if parsed.given?("unit_code") && !parsed.given?("department_code") && revision.department && revision.department.unit_id != revision.unit_id
        issues << issue("department_code", parsed.line, :department_needed)
      end
      issues
    end

    # Other conditions on the date of a revision: a new one with the line's reason, which
    # prevails (RN-04-061).
    def on_same_date(_revision, _same_date, _changes) = [ "create", nil ]
  end
end
