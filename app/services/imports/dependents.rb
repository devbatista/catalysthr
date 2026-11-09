module Imports
  # The dependents (spec 18, kind 3, P-18-08, RN-04-043, D-663): the key is the holder's CPF
  # with the dependent's CPF or, without it, the name. The holder must already be in the
  # company: the employees come first. A line updates without erasing (RN-18-007), and the
  # import never ends a dependent, which stays on the record's screen (D-604). The
  # dependent's CPF is sensitive (D-086).
  class Dependents < PersonKind
    CODE = "dependents".freeze
    FIELDS = %w[name birth_date relationship_type cpf sex irrf family_allowance incapable].freeze
    TYPES = { "holder_cpf" => :cpf, "cpf" => :cpf, "birth_date" => :date, "relationship_type" => :option, "sex" => :option,
      "irrf" => :boolean, "family_allowance" => :boolean, "incapable" => :boolean }.freeze

    def self.code = CODE

    def self.sheets
      column = ->(key, **options) { Column.new(key: key, header: label(key), hint: hint(key), **options) }
      [
        Sheet.new(:dependents, I18n.t("imports.dependents.sheet"), [
          column.("holder_cpf", required: true, digits: 11),
          column.("name", required: true),
          column.("birth_date", required: true),
          column.("relationship_type", required: true,
            options: -> { Dependent::RELATIONSHIP_TYPES.map { |type| [ I18n.t("dependents.relationship_types.#{type}"), type ] } }),
          column.("cpf", digits: 11, sensitive: :cpf),
          column.("sex", options: -> { WorkerProfile::SEXES.map { |sex| [ I18n.t("worker_profiles.sexes.#{sex}"), sex ] } }),
          column.("irrf", options: yes_no),
          column.("family_allowance", options: yes_no),
          column.("incapable", options: yes_no)
        ])
      ]
    end

    def validate(lines)
      lines = Array(lines[sheet_key])
      @profiles = People.profiles_by_cpf(lines.map { |line| People.cpf(line.values["holder_cpf"]) })
      @dependents = Dependent.active.where(worker_profile: @profiles.values).group_by(&:worker_profile_id)
      seen = {}
      lines.map do |line|
        parsed = parse(line, TYPES)
        record = find(parsed) if parsed.issues.empty?
        if record
          key = identity(parsed)
          seen[key] ? parsed.issues << issue("name", line, :repeated_dependent, line: seen[key]) : seen[key] = line.number
        end
        next result(line, issues: parsed.issues) if parsed.issues.any?

        preview(parsed, record)
      end
    end

    def apply(_sheet, values)
      line = Line.new(sheet_key, 0, values)
      @profiles = People.profiles_by_cpf([ People.cpf(values["holder_cpf"]) ])
      @dependents = Dependent.active.where(worker_profile: @profiles.values).group_by(&:worker_profile_id)
      parsed = parse(line, TYPES)
      record = parsed.issues.empty? && find(parsed)
      apply_error!(parsed.issues) if parsed.issues.any?
      apply_error!(model_issues(record, line)) unless record.valid?

      action = record.new_record? ? "create" : (record.changed? ? "update" : "none")
      record.save! unless action == "none"
      [ record, action ]
    end

    private

    def preview(parsed, record)
      return result(parsed.line, issues: model_issues(record, parsed.line)) unless record.valid?
      return result(parsed.line, action: "create") if record.new_record?
      return result(parsed.line) unless record.changed?

      result(parsed.line, action: "update", diff: diff(record, FIELDS.index_by(&:itself)))
    end

    # The holder's active dependent with the CPF or, without it, the name; a new one
    # otherwise. The values given are assigned, the empty ones left as they are.
    def find(parsed)
      profile = @profiles[parsed["holder_cpf"]]
      unless profile
        parsed.issues << issue("holder_cpf", parsed.line, :holder_missing)
        return
      end

      current = @dependents.fetch(profile.id, [])
      name = Normalize.key(parsed["name"])
      record = if parsed["cpf"]
        current.find { |dependent| dependent.cpf == parsed["cpf"] } ||
          current.find { |dependent| dependent.cpf.nil? && Normalize.key(dependent.name) == name }
      else
        current.find { |dependent| Normalize.key(dependent.name) == name }
      end
      record ||= profile.dependents.new(status: "active")
      record.assign_attributes(parsed.values.slice(*FIELDS))
      record
    end

    def identity(parsed)
      [ parsed["holder_cpf"], parsed["cpf"] || Normalize.key(parsed["name"]) ]
    end
  end
end
