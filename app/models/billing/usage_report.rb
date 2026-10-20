require "csv"

module Billing
  # The partner's usage of a month (RN-19-024, D-482, D-618): one line per company of the
  # portfolio, with the employer's document, the name, the peak of employees, the modules
  # used on at least one day, the AI credits and the WhatsApp messages. A closed month is
  # final; the current one is partial, up to the last recorded day (P-19-08). A person
  # employer's CPF goes masked, since the download asks no password (D-086, D-618).
  class UsageReport
    # A cell starting with one of these runs as a formula in a spreadsheet.
    FORMULA_START = /\A[=+\-@\t\r]/
    COLUMNS = %i[document name peak_employees modules ai_credits whatsapp_messages].freeze

    attr_reader :account, :period

    # The months with usage, the current one first, even before its first recorded day.
    def self.periods(account, today = Date.current)
      recorded = UsagePeriod.where(billing_account: account).distinct.pluck(:period)
      ([ UsagePeriod.period_of(today) ] | recorded).sort.reverse
    end

    def initialize(account, period)
      @account = account
      @period = period
    end

    def total
      return @total if defined?(@total)

      @total = UsagePeriod.totals.find_by(billing_account: account, period: period)
    end

    def companies
      @companies ||= UsagePeriod.of_companies.where(billing_account: account, period: period).includes(:company)
        .sort_by { |usage| usage.company.name.downcase }
    end

    def closed?
      total&.closed? || false
    end

    def recorded_through
      DailyUsage.where(billing_account: account, date: UsagePeriod.days(period)).maximum(:date)
    end

    def first_day
      UsagePeriod.days(period).first
    end

    # The CNPJ of the headquarters for a company employer, or the root when the
    # headquarters has another registration; the masked CPF for a person employer.
    def document(company)
      return SensitiveData.mask(company.document, as: :cpf) if company.person?

      type, number = headquarters_registrations[company.id]
      type == "cnpj" ? Cnpj.format(number) : company.formatted_document
    end

    def modules(usage)
      usage.modules.map { |code| I18n.t("modules.#{code}") }.join(", ")
    end

    def filename
      "consumo-#{period}#{"-parcial" unless closed?}.csv"
    end

    # Semicolon-separated with a BOM, as a spreadsheet in Portuguese opens it.
    def to_csv
      "﻿" + CSV.generate(col_sep: ";") do |csv|
        csv << COLUMNS.map { |column| I18n.t("billing.usage_report.columns.#{column}") }
        companies.each do |usage|
          csv << [ document(usage.company), usage.company.name, usage.peak_employees, modules(usage),
            usage.ai_credits, usage.whatsapp_messages ].map { |value| safe(value) }
        end
      end
    end

    private

    def headquarters_registrations
      @headquarters_registrations ||= CrossCompany.scope(Unit, Company.where(id: companies.map(&:company_id)))
        .where(headquarters: true).pluck(:company_id, :registration_type, :registration_number)
        .to_h { |company_id, type, number| [ company_id, [ type, number ] ] }
    end

    def safe(value)
      value.is_a?(String) && value.match?(FORMULA_START) ? "'#{value}" : value
    end
  end
end
