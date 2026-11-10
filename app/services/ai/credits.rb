module Ai
  # The credits of a call that worked (spec 14, RN-14-110 to RN-14-113): the function's weight on
  # the day, the entry in the contract's ledger, the month's usage of the company and of the
  # contract (RN-19-020), and the day's cap. A failed call uses nothing (RN-14-113); the Voyage
  # embeddings use nothing of the client's (RN-14-115).
  module Credits
    module_function

    def for(feature, quantity: 1, on: DailyCap.today)
      feature.credits_for(quantity, weight: AiCreditWeight.credits_on(feature.code, on))
    end

    def charge!(request, company:)
      return if request.credits.zero?

      account = contract_account(company)
      period = UsagePeriod.period_of(DailyCap.today)
      AiCreditEntry.create!(billing_account: account, company: company, ai_request: request, period: period,
        credits: request.credits, kind: "usage")
      add_to_usage(account, company, period, request.credits) if account
      DailyCap.add!(company, request.credits)
    end

    # The partner's contract for a company of its portfolio, or the direct company's own.
    def contract_account(company)
      company.partner ? company.partner.billing_account : company.billing_account
    end

    # The month's rows of the company and of the contract, created when missing; a closed month
    # does not change (RN-19-024).
    def add_to_usage(account, company, period, credits)
      now = Time.current
      rows = [ company.id, nil ].map do |company_id|
        { billing_account_id: account.id, company_id: company_id, period: period, ai_credits: credits, created_at: now, updated_at: now }
      end
      UsagePeriod.upsert_all(rows, unique_by: :index_usage_periods_on_account_period_company,
        on_duplicate: Arel.sql("ai_credits = CASE WHEN usage_periods.closed_at IS NULL THEN usage_periods.ai_credits + EXCLUDED.ai_credits " \
          "ELSE usage_periods.ai_credits END, updated_at = EXCLUDED.updated_at"))
    end
  end
end
