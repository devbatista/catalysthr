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

  ADJUSTMENT_STATUS_PILLS = { "pending" => "pill-warn", "approved" => "pill-ok", "cancelled" => "pill-mute" }.freeze

  def adjustment_status_pill(adjustment)
    tag.span(t("billing.adjustment_statuses.#{adjustment.status}"), class: "pill #{ADJUSTMENT_STATUS_PILLS.fetch(adjustment.status)}")
  end

  # How much of an adjustment the invoices already used (D-621).
  def adjustment_progress(adjustment)
    if adjustment.credit?
      t("billing.adjustment_progress.credit", used: reais(adjustment.applied_cents), total: reais(adjustment.value_cents))
    else
      t("billing.adjustment_progress.invoices", count: adjustment.discount? ? adjustment.cycles : 1, used: adjustment.invoice_lines.size)
    end
  end

  def plan_version_pill(state)
    tag.span(t("billing.version_states.#{state}"), class: "pill #{VERSION_STATE_PILLS.fetch(state)}")
  end

  SERVICE_INVOICE_PILLS = { "pending" => "pill-info", "scheduled" => "pill-info", "authorized" => "pill-ok", "error" => "pill-bad",
    "cancelling" => "pill-warn", "cancelled" => "pill-mute", "cancel_denied" => "pill-bad" }.freeze
  # What the client sees of the team's statuses: a refusal as still being processed, and a
  # refused cancellation as the note it still is.
  CLIENT_SERVICE_INVOICE_STATUSES = { "error" => "pending", "cancel_denied" => "authorized" }.freeze

  # The NFS-e's status (RN-19-106, RN-19-110).
  def service_invoice_pill(note, team:)
    status = team ? note.status : CLIENT_SERVICE_INVOICE_STATUSES.fetch(note.status, note.status)
    label = team ? t("shared.invoices.service_invoice.statuses.#{status}") : t("shared.invoices.service_invoice.client_statuses.#{status}")
    tag.span(label, class: "pill #{SERVICE_INVOICE_PILLS.fetch(status)}")
  end

  # The note's PDF or XML, in the area of who reads the invoice (RN-19-107).
  def service_invoice_file_path(note, kind, team:)
    invoice = note.invoice
    if team
      service_invoice_file_admin_invoice_path(invoice, kind: kind)
    elsif invoice.billing_account.partner?
      service_invoice_file_partner_invoice_path(invoice, kind: kind)
    else
      service_invoice_file_invoice_path(invoice, kind: kind)
    end
  end

  # Each status the note went through, with when (RN-19-111), from its PaperTrail versions.
  def service_invoice_history(note)
    note.versions.sort_by(&:created_at).filter_map do |version|
      status = version.changeset["status"]&.last
      [ version.created_at, status ] if status.present?
    end
  end

  # "ISS retido · PIS 0,65%" or "Nenhuma" (RN-19-102).
  def fiscal_retentions(setting)
    parts = []
    parts << t("billing.retentions.iss") if setting.retain_iss?
    FiscalSetting::RATES.each do |rate|
      value = setting.public_send(rate)
      parts << t("billing.retentions.#{rate}", value: number_to_percentage(value, precision: 2, separator: ",", strip_insignificant_zeros: true)) if value.positive?
    end
    parts.any? ? parts.join(" · ") : t("billing.retentions.none")
  end
end
