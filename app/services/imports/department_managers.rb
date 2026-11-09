module Imports
  # The departments' managers (spec 18, kind 5, P-18-08, RN-04-021, D-664): the key is the
  # department's code with the person's CPF. A line adds the manager and never removes the
  # others, which the department's screen does (RN-18-007). As on that screen, only an active
  # membership of the company with the manager role may be one: the import neither grants the
  # role nor links someone whose invitation is still open.
  class DepartmentManagers < PersonKind
    CODE = "department_managers".freeze
    TYPES = { "cpf" => :cpf }.freeze

    def self.code = CODE
    # Only the department and the CPF: no salary, document nor account.
    def self.sensitive? = false

    def self.sheets
      column = ->(key, **options) { Column.new(key: key, header: label(key), hint: hint(key), **options) }
      [
        Sheet.new(:department_managers, I18n.t("imports.department_managers.sheet"), [
          column.("department_code", required: true, options: -> { Employees.codes(Department) }),
          column.("cpf", required: true, digits: 11),
          column.("name")
        ])
      ]
    end

    def validate(lines)
      lines = Array(lines[sheet_key])
      load(lines.map { |line| People.cpf(line.values["cpf"]) })
      seen = {}
      lines.map do |line|
        parsed, record = build(line)
        if record
          key = [ record.department_id, record.membership_id ]
          seen[key] ? parsed.issues << issue("cpf", line, :repeated_manager, line: seen[key]) : seen[key] = line.number
        end
        next result(line, issues: parsed.issues) if parsed.issues.any?
        next result(line) if record.persisted?

        record.valid? ? result(line, action: "create") : result(line, issues: model_issues(record, line, membership: "cpf"))
      end
    end

    def apply(_sheet, values)
      load([ People.cpf(values["cpf"]) ])
      parsed, record = build(Line.new(sheet_key, 0, values))
      apply_error!(parsed.issues) if parsed.issues.any?
      return [ record, "none" ] if record.persisted?

      apply_error!(model_issues(record, parsed.line, membership: "cpf")) unless record.save
      [ record, "create" ]
    end

    private

    def load(cpfs)
      users = User.where(cpf: cpfs.compact.uniq).to_a
      @memberships = Membership.where(user: users, organization: ActsAsTenant.current_tenant).includes(:user).index_by { |membership| membership.user.cpf }
    end

    # The department and the person's membership, and the link that exists or a new one.
    def build(line)
      parsed = parse(line, TYPES)
      resolve_codes(parsed)
      membership = @memberships[parsed["cpf"]] if parsed["cpf"]
      if parsed["cpf"] && membership.nil?
        parsed.issues << issue("cpf", line, :person_missing)
      elsif membership && !(membership.active? && membership.roles.include?("manager"))
        parsed.issues << issue("cpf", line, :not_active_manager)
      end
      return [ parsed, nil ] if parsed.issues.any?

      department = parsed["department_code"]
      record = department.department_managers.find_or_initialize_by(membership: membership)
      [ parsed, record ]
    end
  end
end
