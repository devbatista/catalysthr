module Imports
  # Where the people are paid (spec 18, kind 4, P-18-08, RN-04-044, D-663): one line is a bank
  # account or a PIX key of the person with the CPF, already in the company. As the primary
  # (the default), it ends the previous one, which stays as history (D-604, CA-04-008); one
  # equal to an active account changes nothing. Who confirms declares that the accounts are in
  # the people's CPF (P-04-17). The number and the key are sensitive (D-086).
  class BankAccounts < PersonKind
    CODE = "bank_accounts".freeze
    ACCOUNT_FIELDS = %w[bank_code branch account_number account_type].freeze
    PIX_FIELDS = %w[pix_key_type pix_key].freeze
    TYPES = { "cpf" => :cpf, "account_type" => :option, "pix_key_type" => :option, "primary" => :boolean }.freeze

    def self.code = CODE
    def self.declaration? = true

    def self.sheets
      column = ->(key, **options) { Column.new(key: key, header: label(key), hint: hint(key), **options) }
      [
        Sheet.new(:bank_accounts, I18n.t("imports.bank_accounts.sheet"), [
          column.("cpf", required: true, digits: 11),
          column.("bank_code", digits: 3),
          column.("branch"),
          column.("account_number", sensitive: :bank_account),
          column.("account_type", options: -> { BankAccount::ACCOUNT_TYPES.map { |type| [ I18n.t("bank_accounts.account_types.#{type}"), type ] } }),
          column.("pix_key_type", options: -> { BankAccount::PIX_KEY_TYPES.map { |type| [ I18n.t("bank_accounts.pix_key_types.#{type}"), type ] } }),
          column.("pix_key", sensitive: :text),
          column.("primary", options: yes_no)
        ])
      ]
    end

    def validate(lines)
      lines = Array(lines[sheet_key])
      load(lines.map { |line| People.cpf(line.values["cpf"]) })
      primaries = {}
      lines.map do |line|
        parsed = parse(line, TYPES)
        account, found = build(parsed) if parsed.issues.empty?
        if account && primary?(parsed)
          cpf = parsed["cpf"]
          parsed.issues << issue("primary", line, :repeated_primary, line: primaries[cpf]) if primaries[cpf]
          primaries[cpf] ||= line.number
        end
        next result(line, issues: parsed.issues) if parsed.issues.any?

        preview(parsed, account, found)
      end
    end

    def apply(_sheet, values)
      line = Line.new(sheet_key, 0, values)
      load([ People.cpf(values["cpf"]) ])
      parsed = parse(line, TYPES)
      account, found = build(parsed) if parsed.issues.empty?
      apply_error!(parsed.issues) if parsed.issues.any?

      if found
        return [ found, "none" ] if found.primary? || !primary?(parsed)

        ::BankAccounts.make_primary!(found)
        return [ found, "update" ]
      end
      apply_error!(model_issues(account, line, model_columns)) unless account.valid?

      record = ::BankAccounts::Register.call(profile: account.worker_profile, attributes: attributes(parsed), primary: primary?(parsed), by: @by)
      apply_error!(model_issues(record, line, model_columns)) unless record.persisted?
      [ record, "create" ]
    end

    private

    def load(cpfs)
      @profiles = People.profiles_by_cpf(cpfs)
      @accounts = BankAccount.active.where(worker_profile: @profiles.values).group_by(&:worker_profile_id)
    end

    def primary?(parsed)
      parsed["primary"] != false
    end

    def preview(parsed, account, found)
      if found
        return result(parsed.line) if found.primary? || !primary?(parsed)

        return result(parsed.line, action: "update", diff: { "primary" => [ I18n.t("imports.no"), I18n.t("imports.yes") ] })
      end
      return result(parsed.line, issues: model_issues(account, parsed.line, model_columns)) unless account.valid?

      result(parsed.line, action: "create")
    end

    # The account the line brings, normalized by the model, and the active one equal to it.
    def build(parsed)
      profile = @profiles[parsed["cpf"]]
      unless profile
        parsed.issues << issue("cpf", parsed.line, :holder_missing)
        return
      end

      account = profile.bank_accounts.new(attributes(parsed).merge(primary: primary?(parsed), declared_by: @by, declared_at: Time.current))
      account.valid?
      found = @accounts.fetch(profile.id, []).find { |current| same?(current, account) }
      [ account, found ]
    end

    def attributes(parsed)
      fields = parsed.given?("pix_key_type") || parsed.given?("pix_key") ? PIX_FIELDS + ACCOUNT_FIELDS : ACCOUNT_FIELDS
      parsed.values.slice(*fields)
    end

    def same?(current, account)
      if account.pix?
        current.pix_key_type == account.pix_key_type && current.pix_key == account.pix_key
      else
        !current.pix? && ACCOUNT_FIELDS.all? { |field| current[field] == account[field] }
      end
    end

    def model_columns
      { base: nil }
    end
  end
end
