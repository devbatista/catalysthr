module Billing
  # Changes to a contract by the CatalystHR team (RN-19-014, RN-19-060, RN-19-061, D-612,
  # D-620). The client's own changes come with block 19e.
  # - An increase (plan, module or add-on) takes effect at once, and the difference for the
  #   days from the change to the end of the cycles already invoiced goes into the next
  #   invoice (CA-19-005). A change of plan is an increase when the month would cost more,
  #   with the same employees and modules; otherwise it is a reduction.
  # - A reduction takes effect after the last day already invoiced: a plan, on the next
  #   cycle; a module or add-on, ending on that day. Without an invoice yet (trial), every
  #   change takes effect at once, with nothing to prorate.
  # - A price migration moves the contract to the plan's version in force, from the first
  #   cycle that starts at least 30 days after the notice (`billing.price_change`).
  # - The partner's activation charges the band and the modules instead of the
  #   pre-activation fee for the rest of the invoiced days (D-612).
  module ContractChanges
    NOTICE_DAYS = 30

    Result = Data.define(:effective_on, :proration)

    module_function

    # The last day already invoiced from the date on, or nil when no invoice covers it.
    def paid_through(account, date)
      account.invoices.where(period_end: date..).maximum(:period_end)
    end

    # The share of a monthly amount for the days from the date to the end of every cycle
    # already invoiced, each cycle by its own length, counting the day of the change
    # (CA-19-005). Half a cent rounds up.
    def prorated_cents(account, date, monthly_cents)
      share = account.invoices.where(period_end: date..).to_a.sum(Rational(0)) do |invoice|
        days = (invoice.period_end - [ date, invoice.period_start ].max).to_i + 1
        Rational(monthly_cents * days, (invoice.period_end - invoice.period_start).to_i + 1)
      end
      share.round(half: :up)
    end

    # What the plan and the modules cost in a month, with the employees the next invoice
    # would charge (D-619).
    def monthly_cents(subscription, date, version: nil, modules: nil, pre_activation: nil)
      account = subscription.billing_account
      employees = Invoicing.employees_basis(account, date) unless account.partner?
      InvoiceLines.new(subscription, date, employees: employees, version: version, modules: modules,
        pre_activation: pre_activation).monthly_cents
    end

    # Another plan; the same plan at a newer price is a price migration (migrate_price).
    def change_plan(subscription, version, by:, today: Date.current)
      raise ArgumentError, "the contract is already on this plan; use migrate_price" if version.plan_id == subscription.plan_version.plan_id

      subscription.with_lock do
        through = paid_through(subscription.billing_account, today)
        current = monthly_cents(subscription, today, version: subscription.plan_version)
        proposed = monthly_cents(subscription, today, version: version)
        if through && proposed <= current
          subscription.update!(next_plan_version: version, next_plan_version_on: through + 1, next_plan_version_reason: "reduction")
          next Result.new(effective_on: through + 1, proration: nil)
        end

        subscription.update!(plan_version: version, next_plan_version: nil, next_plan_version_on: nil, next_plan_version_reason: nil)
        proration = prorate(subscription.billing_account, :plan, t("plan", plan: version.plan.name, date: I18n.l(today)),
          proposed - current, today, by)
        Result.new(effective_on: today, proration: proration)
      end
    end

    # Undoes a reduction or a price migration not yet in force.
    def cancel_scheduled(subscription)
      subscription.with_lock do
        subscription.update!(next_plan_version: nil, next_plan_version_on: nil, next_plan_version_reason: nil)
      end
    end

    # A module contracted, or kept when its removal was scheduled.
    def add_module(subscription, code, by:, today: Date.current)
      subscription.with_lock do
        existing = current_item(subscription, today) { |item| item.kind_module? && item.module == code }
        next keep(existing, today) if existing

        before = monthly_cents(subscription, today)
        subscription.items.create!(kind: "module", module: code, starts_on: today)
        proration = prorate(subscription.billing_account, :module, t("module", module: I18n.t("modules.#{code}"), date: I18n.l(today)),
          monthly_cents(subscription, today) - before, today, by)
        Result.new(effective_on: today, proration: proration)
      end
    end

    def remove_module(subscription, code, today: Date.current)
      subscription.with_lock do
        finish(subscription, current_item(subscription, today) { |item| item.kind_module? && item.module == code }, today)
      end
    end

    # An add-on contracted at its price in force, or kept when its removal was scheduled.
    def add_add_on(subscription, add_on, by:, today: Date.current)
      subscription.with_lock do
        existing = current_item(subscription, today) { |item| item.kind_add_on? && item.add_on_price.add_on_id == add_on.id }
        next keep(existing, today) if existing

        price = add_on.price_on(today)
        subscription.items.create!(kind: "add_on", add_on_price: price, starts_on: today)
        proration = prorate(subscription.billing_account, :add_on,
          t("add_on", add_on: I18n.t("add_ons.names.#{add_on.code}"), date: I18n.l(today)), price.monthly_price_cents, today, by)
        Result.new(effective_on: today, proration: proration)
      end
    end

    def remove_add_on(subscription, add_on, today: Date.current)
      subscription.with_lock do
        finish(subscription, current_item(subscription, today) { |item| item.kind_add_on? && item.add_on_price.add_on_id == add_on.id }, today)
      end
    end

    # The plan's version in force, newer than the contract's, from the first cycle that
    # starts at least 30 days ahead (RN-19-014, D-620). Nil when there is nothing to migrate.
    def migrate_price(subscription, today: Date.current)
      latest = subscription.plan.version_on(today)
      return if latest.nil? || latest.version <= subscription.plan_version.version || subscription.next_plan_version_id == latest.id

      effective = first_cycle_on_or_after(subscription.billing_account.cycle_day, today + NOTICE_DAYS)
      subscription.with_lock do
        subscription.update!(next_plan_version: latest, next_plan_version_on: effective, next_plan_version_reason: "price_migration")
      end
      notify_price_change(subscription, latest, effective)
      Result.new(effective_on: effective, proration: nil)
    end

    # The partner's first day with an active employee (D-612).
    def prorate_activation(subscription, date)
      difference = monthly_cents(subscription, date, pre_activation: false) - subscription.pre_activation_price.monthly_price_cents
      prorate(subscription.billing_account, :activation, t("activation", date: I18n.l(date)), difference, date, nil)
    end

    # The plan versions scheduled up to the day take effect.
    def apply_scheduled(today = Date.current)
      Subscription.where(next_plan_version_on: ..today).find_each do |subscription|
        subscription.with_lock do
          next unless subscription.next_plan_version && subscription.next_plan_version_on <= today

          subscription.update!(plan_version: subscription.next_plan_version, next_plan_version: nil, next_plan_version_on: nil,
            next_plan_version_reason: nil)
        end
      end
    end

    def first_cycle_on_or_after(cycle_day, date)
      start = date.change(day: cycle_day)
      start < date ? start.next_month.change(day: cycle_day) : start
    end

    def current_item(subscription, today, &matches)
      subscription.items.find { |item| item.current?(today) && matches.call(item) }
    end

    # An item whose removal was scheduled stays; one in force is already there.
    def keep(item, today)
      item.update!(ends_on: nil) if item.ends_on
      Result.new(effective_on: today, proration: nil)
    end

    # Ends the item on the last day already invoiced, or at once without an invoice; an
    # item that would end before it starts is removed.
    def finish(subscription, item, today)
      return if item.nil?

      last_day = paid_through(subscription.billing_account, today) || today - 1
      last_day < item.starts_on ? item.destroy! : item.update!(ends_on: last_day)
      Result.new(effective_on: last_day + 1, proration: nil)
    end

    def prorate(account, kind, description, monthly_difference, date, by)
      cents = prorated_cents(account, date, monthly_difference)
      return unless cents.positive?

      account.prorations.create!(kind: kind.to_s, description: description, effective_on: date, total_cents: cents, created_by: by)
    end

    def notify_price_change(subscription, version, effective)
      account = subscription.billing_account
      price = if account.partner?
        I18n.t("billing.summary.partner", price: "R$ #{MoneyCents.format(version.monthly_price_cents)}",
          limit: ActiveSupport::NumberHelper.number_to_delimited(version.employee_limit, locale: :"pt-BR"))
      else
        I18n.t("billing.summary.direct", price: "R$ #{MoneyCents.format(version.price_per_employee_cents)}",
          minimum: "R$ #{MoneyCents.format(version.minimum_monthly_cents)}")
      end
      account.notice_recipients.each do |membership|
        Notifications.notify!("billing.price_change", user: membership.user, membership: membership, subject: subscription,
          dedup_key: "billing.price_change/#{subscription.id}/#{version.id}", path: account.partner? ? "/partner/invoices" : "/invoices",
          name: account.name, plan: version.plan.name, date: I18n.l(effective), price: price)
      end
    end

    def t(key, **params)
      I18n.t("billing.prorations.#{key}", **params)
    end
  end
end
