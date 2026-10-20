module Billing
  # The manual adjustments (RN-19-070, RN-19-071, CA-19-009, D-621): launching one, with the
  # superadmin's approval when the finance team goes above 20% of the next invoice's
  # preview; approving and cancelling; and the lines they take off each invoice issued.
  module Adjustments
    # The waivers first, as they follow the overage; then the discounts; the credits last,
    # so the rest of a credit carries over to the next invoices.
    ORDER = %w[overage_waiver discount credit].freeze

    module_function

    # A new adjustment, approved at once unless it needs the superadmin. Returns it, with
    # the errors when it was not saved.
    def launch(account, attributes, by:)
      adjustment = account.billing_adjustments.new(attributes)
      adjustment.assign_attributes(created_by: by, status: "approved")
      return adjustment unless adjustment.valid?

      if needs_approval?(adjustment, by)
        adjustment.status = "pending"
      else
        adjustment.assign_attributes(approved_by: by, approved_at: Time.current)
      end
      adjustment.save!
      notify_superadmins(adjustment) if adjustment.pending?
      adjustment
    end

    def needs_approval?(adjustment, by)
      !by.superadmin? && share(adjustment) > BillingAdjustment::APPROVAL_SHARE
    end

    # What the adjustment takes off the next invoice's preview, as a share of it (D-619).
    def share(adjustment)
      return adjustment.percent.to_r / 100 if adjustment.percent

      subscription = adjustment.billing_account.subscription
      preview = subscription ? Invoicing.preview_lines(subscription) : []
      total = preview.sum(&:total_cents)
      amount = adjustment.overage_waiver? ? waived_cents(adjustment, preview) : adjustment.value_cents
      return Rational(0) if amount.zero?

      total.positive? ? Rational(amount, total) : Rational(1)
    end

    def approve(adjustment, by:)
      adjustment.with_lock do
        next false unless adjustment.pending?

        adjustment.update!(status: "approved", approved_by: by, approved_at: Time.current)
      end
    end

    def cancel(adjustment, by:)
      adjustment.with_lock do
        next false unless adjustment.cancellable?

        adjustment.update!(status: "cancelled", cancelled_by: by, cancelled_at: Time.current)
      end
    end

    # The adjustment lines of an invoice with the given lines; none takes the invoice below
    # zero. A discount or a waiver uses its cycle even when there is nothing left to take
    # off; a credit only takes what it can and keeps the rest.
    def lines_for(account, lines)
      base = lines.sum(&:total_cents)
      running = base
      open_adjustments(account).filter_map do |adjustment|
        amount = [ amount_for(adjustment, lines, base), running ].min
        next if adjustment.credit? && amount <= 0

        running -= amount
        InvoiceLines::Line.new(kind: "adjustment", description: description(adjustment), quantity: 1, unit_cents: -amount,
          proration_id: nil, billing_adjustment_id: adjustment.id)
      end
    end

    def open_adjustments(account)
      account.billing_adjustments.approved.includes(:invoice_lines).order(:created_at).select(&:open?)
        .sort_by.with_index { |adjustment, index| [ ORDER.index(adjustment.kind), index ] }
    end

    def amount_for(adjustment, lines, base)
      case adjustment.kind
      when "overage_waiver" then waived_cents(adjustment, lines)
      when "credit" then adjustment.remaining_credit_cents
      else adjustment.percent ? (base * adjustment.percent / 100).round(0, half: :up).to_i : adjustment.value_cents
      end
    end

    def waived_cents(adjustment, lines)
      kinds = BillingAdjustment::OVERAGE_SCOPES.fetch(adjustment.overage_scope)
      lines.select { |line| kinds.include?(line.kind) }.sum(&:total_cents)
    end

    # The invoice shows what the adjustment is, never its reason, which is internal.
    def description(adjustment)
      text = case adjustment.kind
      when "overage_waiver" then t("overage_waiver.#{adjustment.overage_scope}")
      when "credit" then t("credit")
      else adjustment.percent ? t("discount_percent", percent: percent(adjustment.percent)) : t("discount")
      end
      return text unless adjustment.discount? && adjustment.cycles > 1

      "#{text} #{t("cycle", number: adjustment.invoice_lines.size + 1, cycles: adjustment.cycles)}"
    end

    # "desconto de 25%", "crédito de R$ 1.000,00" or "isenção do excedente de colaboradores".
    def summary(adjustment)
      case adjustment.kind
      when "overage_waiver" then t("summary.overage_waiver.#{adjustment.overage_scope}")
      when "credit" then t("summary.credit", amount: "R$ #{MoneyCents.format(adjustment.value_cents)}")
      else
        amount = adjustment.percent ? "#{percent(adjustment.percent)}%" : "R$ #{MoneyCents.format(adjustment.value_cents)}"
        t("summary.discount", amount: amount, count: adjustment.cycles)
      end
    end

    def percent(value)
      ActiveSupport::NumberHelper.number_to_rounded(value, precision: 2, strip_insignificant_zeros: true, locale: :"pt-BR")
    end

    # The superadmins, by the bell and e-mail (`platform.adjustment_pending`, D-621).
    def notify_superadmins(adjustment)
      User.superadmin.active.find_each do |user|
        Notifications.notify!("platform.adjustment_pending", user: user, area: "admin", subject: adjustment, path: "/adjustments",
          name: adjustment.billing_account.name, adjustment: summary(adjustment), by: adjustment.created_by.name)
      end
    end

    def t(key, **params)
      I18n.t("billing.adjustments.#{key}", **params)
    end
  end
end
