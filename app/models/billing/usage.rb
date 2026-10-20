module Billing
  # The usage of each contract (RN-19-020 to RN-19-023, D-618). Every day records, for each
  # company still counted, the employees active or on leave on the day and the modules it
  # used, and refreshes the month of each contract from the recorded days. A partner's
  # contract adds up its whole portfolio. The AI credits and the WhatsApp messages come
  # from the ledgers of specs 14 and 15 (RN-14-111, RN-15-064), which also send their own
  # 80% and 100% notices; until they exist, the month keeps them at zero.
  module Usage
    # The companies of a contract stop counting on the day it enters closing (RN-05-084).
    NOT_COUNTED = %w[closing closed].freeze
    # An employment counts on the days it was active or on leave: from the admission to its
    # last day. A terminated one counts up to the day it ended, and not in the read-only
    # period that follows (CA-19-002); one still pending or cancelled never counts.
    COUNTED_EMPLOYMENTS = %w[active on_leave terminated].freeze
    THRESHOLDS = [ 100, 80 ].freeze
    BATCH = 1_000

    CountedCompany = Data.define(:id, :billing_account_id, :since, :modules)

    module_function

    # Records each day of the date's month up to the date for the companies still missing
    # it, then refreshes the month. A day already recorded is kept as it was; a day the job
    # did not run is recorded on the next run. A contract whose month is closed takes no new
    # days.
    def record_through(date)
      period = UsagePeriod.period_of(date)
      closed = UsagePeriod.where(period: period).where.not(closed_at: nil).distinct.pluck(:billing_account_id).to_set
      companies = counted_companies.reject { |company| closed.include?(company.billing_account_id) }
      if companies.any?
        first_day = [ date.beginning_of_month, companies.map(&:since).min ].max
        (first_day..date).each { |day| record_day(day, companies) }
      end
      refresh(period)
    end

    # The companies of the contracts still counted, each with its contract, the day it
    # starts counting (its registration or the contract's start, whichever comes last) and
    # the modules it uses (CompanyModules#contracted): the direct company's own, or the
    # partner's that the partner turned on for it (RN-19-012).
    def counted_companies
      subscriptions = Subscription.where.not(status: NOT_COUNTED).includes(:items, :billing_account).to_a
      by_owner = subscriptions.index_by { |subscription| subscription.billing_account.slice(:owner_type, :owner_id).values }
      partner_ids = by_owner.keys.filter_map { |type, id| id if type == "Partner" }
      direct_ids = by_owner.keys.filter_map { |type, id| id if type == "Company" }
      companies = Company.where(partner_id: partner_ids).or(Company.where(id: direct_ids, partner_id: nil))
        .pluck(:id, :partner_id, :created_at)
      turned_on = CompanyModuleSetting.where(company_id: companies.map(&:first), enabled: true).pluck(:company_id, :module)
        .group_by(&:first).transform_values { |rows| rows.map(&:last) }

      companies.map do |id, partner_id, created_at|
        subscription = partner_id ? by_owner[[ "Partner", partner_id ]] : by_owner[[ "Company", id ]]
        modules = partner_id ? subscription.modules & turned_on.fetch(id, []) : subscription.modules
        CountedCompany.new(id: id, billing_account_id: subscription.billing_account_id,
          since: [ created_at.to_date, subscription.started_on ].max, modules: modules.sort)
      end
    end

    def record_day(day, companies)
      due = companies.select { |company| company.since <= day }
      recorded = DailyUsage.where(date: day).pluck(:company_id).to_set
      missing = due.reject { |company| recorded.include?(company.id) }
      missing.each_slice(BATCH) do |batch|
        counts = counted_employments(batch.map(&:id), day).group(:company_id).count
        rows = batch.map do |company|
          { billing_account_id: company.billing_account_id, company_id: company.id, date: day,
            active_employees: counts.fetch(company.id, 0), modules: company.modules }
        end
        DailyUsage.insert_all(rows, unique_by: %i[company_id date])
      end
    end

    # The employments of the companies that count on the day (COUNTED_EMPLOYMENTS).
    def counted_employments(company_ids, day)
      CrossCompany.scope(Employment, Company.where(id: company_ids))
        .where(status: COUNTED_EMPLOYMENTS, started_on: ..day)
        .where("employments.ended_on IS NULL OR employments.ended_on >= ?", day)
    end

    # The contract's employees active or on leave on the day, by the same rule as the
    # recorded days: for an invoice with no closed month to go by (D-619).
    def active_employees(account, day)
      ids = counted_companies.select { |company| company.billing_account_id == account.id && company.since <= day }.map(&:id)
      ids.empty? ? 0 : counted_employments(ids, day).count
    end

    # The month of each company and of each contract, from the recorded days: the peak of
    # the company, the peak of the contract's daily sum (RN-19-020) and the modules used on
    # at least one day (D-618). A closed month is not touched.
    def refresh(period)
      closed = UsagePeriod.where(period: period).where.not(closed_at: nil).select(:billing_account_id)
      days = DailyUsage.where(date: UsagePeriod.days(period)).where.not(billing_account_id: closed)
      by_company = days.joins("LEFT JOIN LATERAL unnest(daily_usages.modules) AS used(code) ON true")
        .group(:billing_account_id, :company_id)
        .pluck(:billing_account_id, :company_id, Arel.sql("MAX(daily_usages.active_employees)"),
          Arel.sql("array_remove(array_agg(DISTINCT used.code ORDER BY used.code), NULL)"))
      return if by_company.empty?

      contract_peaks = days.group(:billing_account_id, :date).sum(:active_employees)
        .each_with_object(Hash.new(0)) { |((account_id, _date), sum), peaks| peaks[account_id] = [ peaks[account_id], sum ].max }
      contract_modules = by_company.group_by(&:first).transform_values { |rows| rows.flat_map(&:last).uniq.sort }

      rows = by_company.map do |account_id, company_id, peak, modules|
        { billing_account_id: account_id, company_id: company_id, period: period, peak_employees: peak, modules: modules }
      end
      rows += contract_peaks.map do |account_id, peak|
        { billing_account_id: account_id, company_id: nil, period: period, peak_employees: peak, modules: contract_modules[account_id] }
      end
      UsagePeriod.upsert_all(rows, unique_by: :index_usage_periods_on_account_period_company, update_only: %i[peak_employees modules])
    end

    # The partner's first day with an active employee in the portfolio ends the
    # pre-activation: from then on, the band and the modules are charged (RN-19-035, D-612),
    # with the difference for the days already invoiced on the next invoice. The activation
    # happens once.
    def activate_partners(date)
      Subscription.joins(:billing_account).where(billing_accounts: { owner_type: "Partner" }, activated_on: nil)
        .where.not(status: %w[trialing trial_expired]).find_each do |subscription|
        first = DailyUsage.where(billing_account_id: subscription.billing_account_id, date: subscription.started_on..date)
          .where("active_employees > 0").minimum(:date)
        next if first.nil?

        subscription.with_lock do
          next unless subscription.pre_activation?

          subscription.update!(activated_on: first)
          ContractChanges.prorate_activation(subscription, first)
        end
      end
    end

    # 80% and 100% of the partner's band of employees, once each in the month, without
    # blocking anything: the employees above the band are charged on the next invoice
    # (RN-19-022, D-092). A direct company has no band (RN-19-010).
    def alert_band(period)
      UsagePeriod.totals.open.where(period: period)
        .includes(billing_account: [ :owner, { subscription: :plan_version } ]).find_each do |usage|
        band = usage.billing_account.subscription&.employee_band
        next if band.nil?

        threshold = THRESHOLDS.find { |percent| usage.peak_employees * 100 >= band * percent }
        next if threshold.nil? || usage.employees_alerted_percent.to_i >= threshold

        usage.with_lock do
          next if usage.employees_alerted_percent.to_i >= threshold

          usage.update!(employees_alerted_percent: threshold)
          notify_band(usage, threshold, band)
        end
      end
    end

    def notify_band(usage, threshold, band)
      account = usage.billing_account
      account.notice_recipients.each do |membership|
        Notifications.notify!("billing.usage_threshold", user: membership.user, membership: membership, subject: usage,
          dedup_key: "billing.usage_threshold/employees/#{threshold}/#{usage.id}", path: "/partner/usage",
          variant: "employees_#{threshold}", name: account.name, used: usage.peak_employees, limit: band,
          month: I18n.l(UsagePeriod.days(usage.period).first, format: :month_year))
      end
    end

    # Records the month's missing days and closes it: from then on, the month does not
    # change and its report is final (RN-19-023, RN-19-024).
    def close(period)
      record_through(UsagePeriod.days(period).last)
      UsagePeriod.open.where(period: period).update_all(closed_at: Time.current, updated_at: Time.current)
    end
  end
end
