module Imports
  # Admissions in batch (spec 18, section 4.2, D-463, D-668): one admission per line, with the
  # minimal initial registration (D-254), through the same rules as the manual one
  # (AdmissionRegistration, RN-07-010 to RN-07-014): the start is today or later, the
  # employment is born pending and the process starts from the position's or the kind's model.
  # No invitation goes out (P-07-06): the result has "Liberar acesso de todos".
  #
  # The key is the CPF: one that already has an open admission in the company is an error, so
  # sending the file again creates nothing twice (D-668). The HR analyst admits only in their
  # units; a line of another unit is "fora do seu escopo" (RN-18-040, CA-18-005).
  class Admissions < PersonKind
    CODE = "admissions".freeze
    TYPES = { "cpf" => :cpf, "birth_date" => :date, "started_on" => :date, "salary" => :cents, "kind" => :option,
      "category" => :option, "salary_unit" => :option, "weekly_hours" => :decimal }.freeze
    # Where each error of the form shows in the sheet.
    FORM_COLUMNS = { position_id: "position_code", unit_id: "unit_code", department_id: "department_code" }.freeze

    def self.code = CODE

    # The admissions' module, behind its flag (D-648): who admits by hand admits in batch.
    def self.allowed?(ability) = available? && ability.can?(:import, :admissions)
    def self.available? = FeatureFlags.enabled?(FeatureFlags::ADMISSIONS)

    def self.sheets
      list = ->(values, scope) { -> { values.map { |value| [ I18n.t("#{scope}.#{value}"), value ] } } }
      column = ->(key, **options) { Column.new(key: key, header: label(key), hint: hint(key), **options) }
      [
        Sheet.new(:admissions, I18n.t("imports.admissions.sheet"), [
          column.("cpf", required: true, digits: 11),
          column.("name", required: true),
          column.("email"),
          column.("mobile_phone"),
          column.("birth_date"),
          column.("social_name"),
          column.("kind", options: list.(Employment::KINDS, "employments.kinds")),
          column.("category", options: list.(Employment::CLT_CATEGORIES, "employments.categories")),
          column.("started_on", required: true),
          column.("position_code", required: true, options: -> { Employees.codes(Position) }),
          column.("unit_code", required: true, options: -> { Employees.codes(Unit) }),
          column.("department_code", required: true, options: -> { Employees.codes(Department) }),
          column.("salary", sensitive: :money),
          column.("salary_unit", options: list.(EmploymentRevision::SALARY_UNITS, "employment_revisions.salary_units")),
          column.("weekly_hours"),
          column.("justification")
        ])
      ]
    end

    # The preview (RN-18-005, RN-18-006): each admission is recorded and undone, so it goes
    # through every rule of the manual one. Nothing stays (D-462).
    def validate(lines)
      lines = Array(lines[sheet_key])
      @open = open_admissions(lines.filter_map { |line| People.cpf(line.values["cpf"]) })
      seen = {}
      lines.map do |line|
        parsed = read(line)
        repeated(parsed, seen)
        next result(line, issues: parsed.issues) if parsed.issues.any?

        dry_run(parsed)
      end
    end

    # Records a confirmed line (RN-18-008), after the earlier lines.
    def apply(_sheet, values)
      @open = open_admissions([ People.cpf(values["cpf"]) ].compact)
      parsed = read(Line.new(sheet_key, 0, values))
      apply_error!(parsed.issues) if parsed.issues.any?

      registration, issues = create(parsed)
      apply_error!(issues) if issues.any?
      [ registration.admission, "create" ]
    end

    private

    def read(line)
      parsed = parse(line, TYPES)
      resolve_codes(parsed)
      parsed.issues << issue("cpf", line, :admission_open) if parsed["cpf"] && @open.include?(parsed["cpf"])
      unit = parsed["unit_code"]
      parsed.issues << issue("unit_code", line, :out_of_scope) if unit.is_a?(Unit) && !in_scope?(unit)
      parsed
    end

    # The support's assisted import works on the whole company (RN-18-060).
    def in_scope?(unit)
      @import.assisted? || ability.can?(:admit_in, unit)
    end

    def ability
      @ability ||= Ability.new(@by, area: :panel, company: @company)
    end

    # The CPFs with an open admission in the company (D-668).
    def open_admissions(cpfs)
      return Set.new if cpfs.empty?

      Admission.in_status("open").joins(employment: { worker_profile: { membership: :user } }).where(users: { cpf: cpfs })
        .pluck("users.cpf").to_set
    end

    # The same CPF twice in the file.
    def repeated(parsed, seen)
      cpf = parsed["cpf"]
      return unless cpf

      parsed.issues << issue("cpf", parsed.line, :repeated_admission, line: seen[cpf]) if seen[cpf]
      seen[cpf] ||= parsed.line.number
    end

    def dry_run(parsed)
      issues = []
      ActiveRecord::Base.transaction(requires_new: true) do
        _, issues = create(parsed)
        raise ActiveRecord::Rollback
      end
      result(parsed.line, issues: issues, action: "create")
    rescue ActiveRecord::ActiveRecordError => error
      result(parsed.line, issues: [ { "column" => nil, "value" => nil, "message" => I18n.t("imports.errors.unexpected", kind: error.class.name) } ])
    end

    def create(parsed)
      registration = AdmissionRegistration.new(values(parsed))
      return [ registration, [] ] if registration.save(company: @company, by: @by, starter: starter)

      [ registration, form_issues(registration, parsed.line) ]
    end

    def values(parsed)
      kind = parsed["kind"] || "clt"
      {
        name: parsed["name"], cpf: parsed["cpf"], birth_date: parsed["birth_date"], email: parsed["email"],
        mobile_phone: parsed["mobile_phone"], social_name: parsed["social_name"], kind: kind,
        category: parsed["category"] || ("standard" if kind == "clt"), started_on: parsed["started_on"],
        position_id: parsed["position_code"]&.id, unit_id: parsed["unit_code"]&.id, department_id: parsed["department_code"]&.id,
        salary: parsed["salary"] && MoneyCents.decimal(parsed["salary"]), salary_unit: parsed["salary_unit"] || "month",
        weekly_hours: parsed["weekly_hours"], justification: parsed["justification"]
      }
    end

    # Who starts the process, as in the admissions' screen.
    def starter
      return @starter if defined?(@starter)

      @starter = Membership.with_access.find_by(user: @by, organization: @company) ||
        (Membership.with_access.find_by(user: @by, organization: @company.partner) if @company.partner)
    end

    def form_issues(form, line)
      form.errors.map do |error|
        column = FORM_COLUMNS.fetch(error.attribute) { error.attribute.to_s if sheet.column(error.attribute.to_s) }
        { "column" => column, "value" => column && line.values[column], "message" => error.full_message }
      end
    end
  end
end
