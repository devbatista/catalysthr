module Ai
  # The notices of 80% and 100% of the month's AI credits (spec 14, RN-14-112, D-092, D-125,
  # CA-14-011), once each in the month, to the partner's administrator or to the direct company's
  # HR administrator (the contract's responsible first). Past the quota nothing is blocked: the
  # excess goes to the invoice (RN-19-022). A contract whose quota is zero has no percent, so it
  # gets no notice (D-670).
  module UsageAlerts
    THRESHOLDS = Billing::Usage::THRESHOLDS

    module_function

    def call(period = UsagePeriod.period_of(DailyCap.today))
      UsagePeriod.totals.open.where(period: period).where("ai_credits > 0")
        .includes(billing_account: [ :owner, { subscription: :plan_version } ]).find_each do |usage|
        subscription = usage.billing_account.subscription
        next if subscription.nil?

        quota = subscription.monthly_quotas(usage.peak_employees)[:ai_credits].to_i
        next unless quota.positive?

        threshold = THRESHOLDS.find { |percent| usage.ai_credits * 100 >= quota * percent }
        next if threshold.nil? || usage.ai_alerted_percent.to_i >= threshold

        usage.with_lock do
          next if usage.ai_alerted_percent.to_i >= threshold

          usage.update!(ai_alerted_percent: threshold)
          notify(usage, threshold, quota)
        end
      end
    end

    def notify(usage, threshold, quota)
      account = usage.billing_account
      path = account.partner? ? "/partner/usage" : "/invoices"
      account.notice_recipients.each do |membership|
        Notifications.notify!("billing.usage_threshold", user: membership.user, membership: membership, subject: usage,
          dedup_key: "billing.usage_threshold/ai/#{threshold}/#{usage.id}", path: path,
          variant: "ai_#{threshold}", name: account.name, used: usage.ai_credits, limit: quota,
          month: I18n.l(UsagePeriod.days(usage.period).first, format: :month_year))
      end
    end
  end
end
