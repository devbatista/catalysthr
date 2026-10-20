# Amounts and summaries of the billing screens (spec 19). Amounts are kept in cents.
module BillingHelper
  def reais(cents)
    cents.nil? ? "—" : "R$ #{MoneyCents.format(cents)}"
  end

  # "R$ 1.500,00 por mês, até 500 colaboradores" or "R$ 12,00 por colaborador, mínimo de R$ 300,00".
  def plan_price_summary(version)
    return "—" if version.nil?

    if version.plan.partner?
      t("billing.summary.partner", price: reais(version.monthly_price_cents), limit: number_with_delimiter(version.employee_limit))
    else
      t("billing.summary.direct", price: reais(version.price_per_employee_cents), minimum: reais(version.minimum_monthly_cents))
    end
  end

  # "Vigente", "Futura" or "Substituída", by the version in force today. A version is
  # replaced by a later one or by another of the same date registered after it (D-611).
  def plan_version_state(version)
    plan = version.plan
    return :current if version == plan.version_on

    corrected = plan.plan_versions.any? { |other| other.valid_from == version.valid_from && other.version > version.version }
    corrected || version.valid_from <= Date.current ? :replaced : :future
  end

  VERSION_STATE_PILLS = { current: "pill-ok", future: "pill-info", replaced: "pill-mute" }.freeze

  STATUS_PILLS = {
    "trialing" => "pill-info", "active" => "pill-ok", "past_due" => "pill-warn", "read_only" => "pill-bad",
    "closing" => "pill-bad", "closed" => "pill-mute", "trial_expired" => "pill-warn", "cancel_scheduled" => "pill-warn"
  }.freeze

  # The subscription's status, and "Pré-ativação" for a partner before the first active
  # employee (RN-19-035).
  def subscription_status_pill(subscription)
    status = tag.span(t("billing.subscription_statuses.#{subscription.status}"), class: "pill #{STATUS_PILLS.fetch(subscription.status)}")
    return status unless subscription.pre_activation?

    safe_join([ status, tag.span(t("billing.pre_activation"), class: "pill pill-mute") ], " ")
  end

  INVOICE_STATUS_PILLS = { "draft" => "pill-mute", "open" => "pill-info", "paid" => "pill-ok", "overdue" => "pill-bad",
    "void" => "pill-mute" }.freeze

  def invoice_status_pill(invoice)
    tag.span(t("billing.invoice_statuses.#{invoice.status}"), class: "pill #{INVOICE_STATUS_PILLS.fetch(invoice.status)}")
  end

  def plan_version_pill(state)
    tag.span(t("billing.version_states.#{state}"), class: "pill #{VERSION_STATE_PILLS.fetch(state)}")
  end
end
