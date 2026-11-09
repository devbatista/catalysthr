module Imports
  # Employees and their employments (spec 18, kind 2, P-18-08, D-663): the key is the CPF with
  # the registration number. A new line goes through the "Novo colaborador" rules (D-600,
  # D-602): a CPF that already has an account keeps the same person, nothing of another
  # company changes, and no invitation nor eSocial event goes out (RN-18-020, CA-18-004). The
  # people get the portal later, by "Convidar todos sem acesso".
  #
  # A line of an employment already registered updates only the record: its conditions
  # change as a revision with a date and a reason (D-207), so a different one is an error.
  # The sign-in e-mail and mobile phone, the name and the birth date are only a new person's;
  # for someone who exists, the record's own e-mail and phone are the ones that change
  # (CA-18-003, D-209, D-663).
  class Employees < PersonKind
    CODE = "employees".freeze

    # The record's fields read from the sheet, by column (RN-04-041).
    PROFILE_FIELDS = %w[
      social_name sex race marital_status education_level birth_city birth_state birth_country nationality
      personal_email personal_phone postal_code street street_number complement district city state ibge_city_code
      rg_number rg_issuer rg_state rg_issued_on ctps_number ctps_series ctps_state pis_nis voter_id cnh_number
      cnh_category cnh_expires_on
    ].freeze
    DOCUMENTS = %w[rg_number ctps_number pis_nis voter_id cnh_number].freeze
    # The conditions of the employment and of its revision in force, compared on an update.
    CONDITIONS = %w[kind category started_on position_code unit_code department_code salary salary_unit
      variable_salary_description weekly_hours].freeze
    # Where each error of the form shows in the sheet.
    FORM_COLUMNS = { position_id: "position_code", unit_id: "unit_code", department_id: "department_code" }.freeze
    TYPES = {
      "cpf" => :cpf, "birth_date" => :date, "started_on" => :date, "salary" => :cents, "weekly_hours" => :decimal,
      "rg_issued_on" => :date, "cnh_expires_on" => :date, "kind" => :option, "category" => :option,
      "salary_unit" => :option, "sex" => :option, "race" => :option, "marital_status" => :option,
      "education_level" => :option, "cnh_category" => :option
    }.freeze

    def self.code = CODE

    def self.sheets
      list = ->(values, scope) { -> { values.map { |value| [ I18n.t("#{scope}.#{value}"), value ] } } }
      states = -> { Unit::STATES.map { |state| [ state, state ] } }
      column = lambda do |key, **options|
        Column.new(key: key, header: label(key), hint: hint(key), **options)
      end
      [
        Sheet.new(:employees, I18n.t("imports.employees.sheet"), [
          column.("cpf", required: true, digits: 11),
          column.("name", required: true),
          column.("birth_date", required: true),
          column.("registration_number", required: true),
          column.("started_on", required: true),
          column.("kind", options: list.(Employment::KINDS, "employments.kinds")),
          column.("category", options: list.(Employment::CLT_CATEGORIES, "employments.categories")),
          column.("position_code", required: true, options: -> { codes(Position) }),
          column.("unit_code", required: true, options: -> { codes(Unit) }),
          column.("department_code", options: -> { codes(Department) }),
          column.("salary", sensitive: :money),
          column.("salary_unit", options: list.(EmploymentRevision::SALARY_UNITS, "employment_revisions.salary_units")),
          column.("variable_salary_description"),
          column.("weekly_hours"),
          column.("justification"),
          column.("email"),
          column.("mobile_phone"),
          column.("personal_email"),
          column.("personal_phone"),
          column.("social_name"),
          column.("sex", options: list.(WorkerProfile::SEXES, "worker_profiles.sexes")),
          column.("race", options: list.(WorkerProfile::RACES, "worker_profiles.races")),
          column.("marital_status", options: list.(WorkerProfile::MARITAL_STATUSES, "worker_profiles.marital_statuses")),
          column.("education_level", options: list.(WorkerProfile::EDUCATION_LEVELS, "worker_profiles.education_levels")),
          column.("birth_city"),
          column.("birth_state", options: states),
          column.("birth_country"),
          column.("nationality"),
          column.("postal_code", digits: 8),
          column.("street"),
          column.("street_number"),
          column.("complement"),
          column.("district"),
          column.("city"),
          column.("state", options: states),
          column.("ibge_city_code", digits: 7),
          column.("rg_number", sensitive: :text),
          column.("rg_issuer"),
          column.("rg_state", options: states),
          column.("rg_issued_on"),
          column.("ctps_number", sensitive: :text),
          column.("ctps_series"),
          column.("ctps_state", options: states),
          column.("pis_nis", digits: 11, sensitive: :text),
          column.("voter_id", sensitive: :text),
          column.("cnh_number", sensitive: :text),
          column.("cnh_category", options: -> { WorkerProfile::CNH_CATEGORIES.map { |category| [ category, category ] } }),
          column.("cnh_expires_on")
        ])
      ]
    end

    # The company's codes, for the template's lists (D-662).
    def self.codes(model)
      model.where.not(code: nil).order(:code).pluck(:code).map { |code| [ code, code ] }
    end

    # The preview (RN-18-005, RN-18-006): a new employment is recorded and undone, so it goes
    # through every rule of the manual form; an existing one is compared. Nothing stays.
    def validate(lines)
      lines = Array(lines[sheet_key])
      @profiles = People.profiles_by_cpf(lines.map { |line| People.cpf(line.values["cpf"]) })
      numbers = lines.filter_map { |line| line.values["registration_number"]&.strip }
      @employments = Employment.where(registration_number: numbers).includes(revisions: %i[position unit department]).index_by(&:registration_number)
      seen = {}
      numbers_seen = {}
      lines.map do |line|
        parsed = read(line)
        repeated(parsed, seen, numbers_seen)
        next result(line, issues: parsed.issues) if parsed.issues.any?

        preview(parsed)
      end
    end

    # Records a confirmed line (RN-18-008), with what the earlier lines recorded.
    def apply(_sheet, values)
      line = Line.new(sheet_key, 0, values)
      @profiles = People.profiles_by_cpf([ People.cpf(values["cpf"]) ])
      @employments = Employment.where(registration_number: values["registration_number"]&.strip).includes(revisions: %i[position unit department])
        .index_by(&:registration_number)
      parsed = read(line)
      apply_error!(parsed.issues) if parsed.issues.any?

      employment = @employments[parsed["registration_number"]]
      if employment
        profile = employment.worker_profile
        issues = existing(parsed, employment, profile)
        apply_error!(issues) if issues.any?
        return [ profile, "none" ] unless profile.changed?

        profile.save!
        [ profile, "update" ]
      else
        record, issues = create(parsed)
        apply_error!(issues) if issues.any?
        [ record, "create" ]
      end
    end

    private

    def read(line)
      parsed = parse(line, TYPES)
      parsed.values["registration_number"] = parsed["registration_number"]&.strip
      resolve_codes(parsed)
      parsed
    end

    # The same employment twice, or a registration number of two CPFs, in the file.
    def repeated(parsed, seen, numbers_seen)
      cpf = parsed["cpf"]
      number = parsed["registration_number"]
      return unless cpf && number

      key = [ cpf, number ]
      if seen[key]
        parsed.issues << issue("registration_number", parsed.line, :repeated_employment, line: seen[key])
      elsif numbers_seen[number] && numbers_seen[number].first != cpf
        parsed.issues << issue("registration_number", parsed.line, :registration_repeated, line: numbers_seen[number].last)
      end
      seen[key] ||= parsed.line.number
      numbers_seen[number] ||= [ cpf, parsed.line.number ]
    end

    def preview(parsed)
      employment = @employments[parsed["registration_number"]]
      return dry_run(parsed) unless employment

      profile = employment.worker_profile
      issues = existing(parsed, employment, profile)
      return result(parsed.line, issues: issues) if issues.any?
      return result(parsed.line) unless profile.changed?

      result(parsed.line, action: "update", diff: diff(profile, PROFILE_FIELDS.index_by(&:itself)))
    end

    # An employment already registered: of this person, with the same conditions, and the
    # record's fields assigned without erasing (RN-18-007).
    def existing(parsed, employment, profile)
      profile_cpf = profile&.user&.cpf
      return [ issue("registration_number", parsed.line, :registration_taken) ] if profile_cpf != parsed["cpf"]

      issues = conditions(parsed, employment)
      profile.assign_attributes(profile_values(parsed))
      issues += model_issues(profile, parsed.line) unless profile.valid?
      issues
    end

    def conditions(parsed, employment)
      revision = employment.effective_revision
      current = {
        "kind" => employment.kind, "category" => employment.category, "started_on" => employment.started_on,
        "position_code" => revision&.position, "unit_code" => revision&.unit, "department_code" => revision&.department,
        "salary" => revision&.salary_cents, "salary_unit" => revision&.salary_unit,
        "variable_salary_description" => revision&.variable_salary_description,
        "weekly_hours" => revision&.weekly_hours
      }
      CONDITIONS.select { |column| parsed.given?(column) && !same?(parsed[column], current[column]) }
        .map { |column| issue(column, parsed.line, :condition_differs) }
    end

    def same?(given, current)
      return given.to_d == current.to_d if given.is_a?(BigDecimal) && current
      return given.to_s.squish == current.to_s.squish if given.is_a?(String)

      given == current
    end

    # A new employment, recorded and undone: the same rules as the manual form (RN-18-005).
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

    # The person (or the one with that CPF), the employment and its first revision, then the
    # record's fields. Returns the employment and the errors.
    def create(parsed)
      profile = @profiles[parsed["cpf"]]
      form = profile ? EmploymentRegistration.new(employment_values(parsed)) : EmployeeRegistration.new(employment_values(parsed).merge(person_values(parsed)))
      saved = profile ? form.save(profile: profile, by: @by) : form.save(company: @company, by: @by)
      return [ nil, form_issues(form, parsed.line) ] unless saved

      profile ||= form.profile
      profile.assign_attributes(profile_values(parsed))
      return [ nil, model_issues(profile, parsed.line) ] unless profile.save

      [ form.employment, [] ]
    end

    def employment_values(parsed)
      {
        kind: parsed["kind"] || "clt", category: parsed["category"] || (parsed["kind"].in?([ nil, "clt" ]) ? "standard" : nil),
        registration_number: parsed["registration_number"], started_on: parsed["started_on"],
        position_id: parsed["position_code"]&.id, unit_id: parsed["unit_code"]&.id, department_id: parsed["department_code"]&.id,
        salary: parsed["salary"] && MoneyCents.decimal(parsed["salary"]), salary_unit: parsed["salary_unit"] || "month",
        variable_salary_description: parsed["variable_salary_description"], weekly_hours: parsed["weekly_hours"],
        justification: parsed["justification"]
      }
    end

    # Only a new person's (D-602, D-663): an account that exists keeps them.
    def person_values(parsed)
      { name: parsed["name"], cpf: parsed["cpf"], birth_date: parsed["birth_date"], email: parsed["email"],
        mobile_phone: parsed["mobile_phone"], social_name: parsed["social_name"] }
    end

    def profile_values(parsed)
      parsed.values.slice(*PROFILE_FIELDS)
    end

    def form_issues(form, line)
      form.errors.map do |error|
        column = FORM_COLUMNS.fetch(error.attribute) { error.attribute.to_s if sheet.column(error.attribute.to_s) }
        { "column" => column, "value" => column && line.values[column], "message" => error.full_message }
      end
    end
  end
end
