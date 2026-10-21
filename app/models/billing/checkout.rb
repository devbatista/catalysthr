module Billing
  # The contracting by the client, during the trial or in the 30 days after it (RN-19-033,
  # RN-19-034, D-622): the financial responsible chooses the plan and the modules, and the
  # first cycle's invoice comes out at once, due that day, with the PIX of the day. The
  # contract only starts when the PIX is paid; until then the trial goes on, and the cycle
  # starts on the invoice's day. Contracting again the same day replaces the invoice; one
  # not paid is voided the next day, and the client contracts again. A partner with no
  # active employee in the portfolio pays the pre-activation fee (RN-19-035, D-612).
  module Checkout
    STATUSES = CompanyModules::TRIAL_STATUSES

    # The contract is not in a trial (any more), or the choice is not valid.
    class Error < StandardError; end

    module_function

    def open?(subscription)
      subscription.present? && subscription.status.in?(STATUSES)
    end

    # The checkout's invoice still waiting for its PIX today.
    def pending_invoice(account, today = Date.current)
      account.invoices.find_by(checkout: true, status: "open", period_start: today)
    end

    # The choice, applied to the contract still in its trial, and the first cycle's invoice.
    def start(account, plan:, modules:, today: Date.current)
      subscription = account.subscription
      subscription.with_lock do
        raise Error, "not in a trial" unless open?(subscription)

        version = plan&.version_on(today)
        raise Error, "plan not offered" unless version && Plan.offered_to(account).exists?(plan.id)

        void_open(account, "checkout_replaced")
        choose(subscription, version, modules & PlanModule::MODULES, today)
        account.update!(cycle_day: BillingAccount.cycle_day_for(today))
        employees = Invoicing.employees_basis(account, today) unless account.partner?
        lines = InvoiceLines.new(subscription, today, employees: employees,
          pre_activation: account.partner? && subscription.activated_on.nil?).lines
        invoice = Invoicing.create(account, today, nil, lines + Adjustments.lines_for(account, lines), checkout: true)
        # A credit that covers everything leaves nothing to pay: the contract starts now (D-624).
        activate(invoice) if invoice.paid?
        invoice
      end
    end

    # The plan version and the modules chosen; the add-ons stay. A partner with no active
    # employee today starts on the pre-activation fee; a direct company, or a partner with
    # one, is active from the first day.
    def choose(subscription, version, modules, today)
      account = subscription.billing_account
      pre_activation = account.partner? && Usage.active_employees(account, today).zero?
      price = PreActivationPrice.on(today) if pre_activation
      raise Error, "no pre-activation price" if pre_activation && price.nil?

      subscription.update!(plan_version: version, next_plan_version: nil, next_plan_version_on: nil, next_plan_version_reason: nil,
        pre_activation_price: price, activated_on: (today unless pre_activation))
      subscription.items.select(&:kind_module?).each do |item|
        next if modules.include?(item.module) && item.ends_on.nil?

        item.starts_on < today ? item.update!(ends_on: today - 1) : item.destroy!
      end
      (modules - subscription.items.reload.select { |item| item.kind_module? && item.current?(today) }.map(&:module)).each do |code|
        subscription.items.create!(kind: "module", module: code, starts_on: today)
      end
    end

    # Paid: the contract starts on the invoice's day (RN-19-033).
    def activate(invoice)
      account = invoice.billing_account
      subscription = account.subscription
      subscription.with_lock do
        next unless open?(subscription)

        subscription.update!(status: "active", started_on: invoice.period_start)
        account.update!(cycle_day: BillingAccount.cycle_day_for(invoice.period_start))
      end
    end

    # The checkout's invoices of earlier days still not paid, voided (D-622). Runs after the
    # daily check of the PIX, so one paid at the end of the day is already paid.
    def void_unpaid(today = Date.current)
      Invoice.where(checkout: true, status: "open", period_start: ...today).find_each do |invoice|
        invoice.with_lock { void(invoice, "checkout_unpaid") if invoice.open? }
      end
    end

    def void_open(account, reason)
      account.invoices.where(checkout: true, status: "open").find_each { |invoice| void(invoice, reason) }
    end

    def void(invoice, reason)
      invoice.update!(status: "void", void_reason: reason, voided_at: Time.current)
    end
  end
end
