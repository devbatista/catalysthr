module Billing
  # The Revenue block of the CatalystHR team's panel (RN-19-090, D-610, D-626):
  # - the monthly recurring revenue: the plan (or the partner's pre-activation fee), the
  #   modules and the add-ons of each charged contract's next cycle, priced as its invoice
  #   would be, without the adjustments and the overage. A direct company's employees are
  #   those of its last recorded day;
  # - the overage invoiced this month: the overage lines of the invoices issued in it;
  # - the late payments: the amount of the overdue invoices and the contracts with one, by
  #   their status in the schedule;
  # - the cancellations scheduled and the trials running;
  # - the trial conversion of the last 90 days: of the trials that ended in them, those
  #   contracted, in the trial (which ends it) or in the 30 days after it.
  class RevenueSummary
    CONVERSION_DAYS = 90
    OVERAGE_KINDS = %w[overage_employees overage_ai overage_whatsapp].freeze
    LATE_STATUSES = %w[past_due read_only closing].freeze

    Recurring = Data.define(:monthly_cents, :add_on_cents, :contracts) do
      def total_cents
        monthly_cents + add_on_cents
      end
    end

    Conversion = Data.define(:ended, :converted) do
      def percent
        converted * 100 / ended if ended.positive?
      end
    end

    attr_reader :today

    def initialize(today = Date.current)
      @today = today
    end

    def recurring
      @recurring ||= begin
        subscriptions = Subscription.where(status: Invoicing::BILLABLE)
          .includes(:billing_account, :pre_activation_price, { plan_version: %i[plan plan_modules] },
            { next_plan_version: %i[plan plan_modules] }, items: { add_on_price: :add_on })
          .to_a
        account_ids = subscriptions.map(&:billing_account_id)
        last_starts = Invoice.where(billing_account_id: account_ids).where.not(status: "void").group(:billing_account_id).maximum(:period_start)
        employees = DailyUsage.latest_totals(account_ids)

        lines = subscriptions.flat_map do |subscription|
          start = Invoicing.next_cycle_start(subscription, last_start: last_starts[subscription.billing_account_id])
          InvoiceLines.new(subscription, start, employees: employees.fetch(subscription.billing_account_id, 0)).recurring_lines
        end
        add_ons, monthly = lines.partition { |line| line.kind == "add_on" }
        Recurring.new(monthly_cents: monthly.sum(&:total_cents), add_on_cents: add_ons.sum(&:total_cents), contracts: subscriptions.size)
      end
    end

    def overage_invoiced_cents
      InvoiceLine.joins(:invoice).where(kind: OVERAGE_KINDS)
        .where(invoices: { issued_at: today.beginning_of_month.beginning_of_day..today.end_of_month.end_of_day })
        .where.not(invoices: { status: "void" }).sum(:total_cents)
    end

    def overdue_cents
      Invoice.overdue.sum(:total_cents)
    end

    # The contracts with an overdue invoice, by status: past_due, read_only, closing.
    def late_contracts
      counts = Subscription.where(status: LATE_STATUSES, billing_account_id: Invoice.overdue.select(:billing_account_id)).group(:status).count
      LATE_STATUSES.index_with { |status| counts.fetch(status, 0) }
    end

    def scheduled_cancellations
      Subscription.where.not(cancel_on: nil).where.not(status: %w[closing closed])
        .includes(billing_account: :owner).order(:cancel_on).to_a
    end

    def trials_running
      Subscription.trialing.count
    end

    def conversion
      @conversion ||= begin
        trials = Subscription.where(trial_ends_on: (today - CONVERSION_DAYS)..).pluck(:billing_account_id, :trial_ends_on)
        paid = Invoice.where(billing_account_id: trials.map(&:first), checkout: true, status: "paid").group(:billing_account_id).minimum(:paid_at)
        window = (today - CONVERSION_DAYS)...today
        ended = trials.map { |account_id, trial_ends_on| [ trial_ends_on, paid[account_id]&.to_date ] }
          .select { |trial_ends_on, paid_on| window.cover?([ trial_ends_on, paid_on ].compact.min) }
        Conversion.new(ended: ended.size, converted: ended.count { |_, paid_on| paid_on })
      end
    end
  end
end
