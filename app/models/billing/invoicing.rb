module Billing
  # Issues the invoices of each contract's cycles (RN-19-040, RN-19-041, D-619). The cycle
  # starts on the contract's cycle day (P-19-11); its invoice is issued 3 days before and is
  # due on the first day, charging the month that starts. The first cycle starts on the
  # contract's start, and its invoice is issued at once, due that day (RN-19-033). The
  # overage is the one of the last closed month, charged once (D-619), and the prorations of
  # the changes made since the last invoice go in too (RN-19-060, D-620). Issuing again
  # changes nothing: each cycle has one invoice, and two runs at the same time wait for each
  # other.
  module Invoicing
    # The statuses still charged; the trial, its end and the closing are not (RN-19-034,
    # RN-19-050). The cancellation stops the cycles with block 19f.
    BILLABLE = %w[active past_due read_only cancel_scheduled].freeze
    LEAD_DAYS = 3

    module_function

    # The invoices issued for the cycles starting up to `today + lead`.
    def issue_due(subscription, today = Date.current, lead: LEAD_DAYS)
      return [] unless subscription.status.in?(BILLABLE)

      cycle_starts(subscription, today + lead).filter_map { |start| issue(subscription, start, today) }
    end

    def cycle_starts(subscription, through)
      account = subscription.billing_account
      last = account.invoices.maximum(:period_start)
      start = last ? next_cycle(last, account.cycle_day) : subscription.started_on
      starts = []
      while start <= through
        starts << start
        start = next_cycle(start, account.cycle_day)
      end
      starts
    end

    def next_cycle(date, cycle_day)
      date.next_month.change(day: cycle_day)
    end

    def issue(subscription, start, today)
      account = subscription.billing_account
      invoice = subscription.with_lock do
        next if account.invoices.exists?(period_start: start)

        usage = billable_usage(account, today)
        employees = employees_basis(account, today) unless account.partner?
        lines = InvoiceLines.new(subscription, start, usage: usage, employees: employees, prorations: account.prorations.pending.to_a).lines
        create(account, start, usage, lines)
      end
      notify(invoice) if invoice
      invoice
    end

    # The direct company's employees to charge: the peak of the last closed month, or those
    # active on the day when there is none (D-619).
    def employees_basis(account, today)
      last = UsagePeriod.totals.where(billing_account: account).where.not(closed_at: nil).order(period: :desc).first
      last&.peak_employees || Usage.active_employees(account, today)
    end

    # The month before the issue, closed, unless an earlier invoice already charged it.
    def billable_usage(account, today)
      period = UsagePeriod.period_of(today.prev_month)
      return if account.invoices.exists?(usage_period: period)

      UsagePeriod.totals.where.not(closed_at: nil).find_by(billing_account: account, period: period)
    end

    def create(account, start, usage, lines)
      # The numbers follow each other with no gap; two invoices issued at the same time wait.
      Invoice.connection.execute("SELECT pg_advisory_xact_lock(hashtext('invoices/number'))")
      invoice = account.invoices.new(number: (Invoice.maximum(:number) || 0) + 1, period_start: start,
        period_end: next_cycle(start, account.cycle_day) - 1, due_on: start, status: "open",
        total_cents: lines.sum(&:total_cents), usage_period: usage&.period, issued_at: Time.current)
      lines.each.with_index(1) do |line, position|
        invoice.lines.new(position: position, kind: line.kind, description: line.description, quantity: line.quantity,
          unit_cents: line.unit_cents, total_cents: line.total_cents, proration_id: line.proration_id)
      end
      invoice.save!
      invoice
    end

    # The contract's responsible is told (`billing.invoice_issued`, RN-19-041).
    def notify(invoice)
      account = invoice.billing_account
      path = account.partner? ? "/partner/invoices/#{invoice.id}" : "/invoices/#{invoice.id}"
      account.notice_recipients.each do |membership|
        Notifications.notify!("billing.invoice_issued", user: membership.user, membership: membership, subject: invoice, path: path,
          name: account.name, number: invoice.display_number, total: "R$ #{MoneyCents.format(invoice.total_cents)}",
          due: I18n.l(invoice.due_on), period_start: I18n.l(invoice.period_start), period_end: I18n.l(invoice.period_end))
      end
    end
  end
end
