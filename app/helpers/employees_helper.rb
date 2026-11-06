module EmployeesHelper
  STATUS_PILLS = { "pending" => "pill-info", "active" => "pill-ok", "on_leave" => "pill-warn",
                   "terminated" => "pill-mute", "cancelled" => "pill-mute" }.freeze

  def employment_status_pill(employment)
    return "—" if employment.nil?

    tag.span(t("employments.statuses.#{employment.status}"), class: "pill #{STATUS_PILLS.fetch(employment.status)}")
  end

  # "CLT · Empregado", "Estágio".
  def employment_kind(employment)
    [ t("employments.kinds.#{employment.kind}"), (t("employments.categories.#{employment.category}") if employment.category) ]
      .compact.join(" · ")
  end

  # "R$ 2.500,00 por mês", hidden until the pay section is revealed (RN-02-052).
  def revision_salary(revision)
    return t("employment_revisions.variable_only", description: revision.variable_salary_description) if revision.paid_by_variable_only?

    amount = reveal_confirmed(revision, :salary_cents, as: :money, section: :pay)
    "#{amount} #{t("employment_revisions.salary_units.#{revision.salary_unit}")}"
  end

  # "Matriz › Produção", with the allocation client when there is one (RN-04-092).
  def revision_place(revision)
    place = [ revision.unit.name, revision.department&.name ].compact.join(" › ")
    revision.allocation_client ? t("panel.employees.show.at_client", place: place, client: revision.allocation_client.name) : place
  end

  # A link that keeps the sections already shown and adds this one.
  def reveal_link(profile, section)
    return if impersonating? || revealed_sections.include?(section.to_s)

    link_to t("panel.employees.show.reveal"), employee_path(profile, reveal: revealed_sections + [ section.to_s ]),
      class: "link-button text-sm", rel: "nofollow"
  end

  def option_label(group, value)
    value.nil? ? "—" : t("#{group}.#{value}")
  end

  def yes_no(value)
    value.nil? ? "—" : t(value ? "panel.employees.show.yes" : "panel.employees.show.no")
  end

  # The CPF formatted, or partly masked during an impersonate (RN-02-086).
  def employee_cpf(user)
    impersonating? ? reveal_sensitive(user, :cpf, as: :cpf) : Cpf.format(reveal_sensitive(user, :cpf, as: :cpf))
  end

  def worker_address(profile)
    if profile.lives_abroad?
      return [ profile.foreign_address, profile.foreign_country ].compact_blank.join(" · ")
    end

    street = [ profile.street, profile.street_number ].compact_blank.join(", ")
    city = [ profile.city, profile.state ].compact_blank.join(" / ")
    [ street, profile.complement, profile.district, city, profile.postal_code&.sub(/\A(\d{5})(\d{3})\z/, '\1-\2') ].compact_blank.join(" · ")
  end

  # The disability in one sentence, shown only through reveal_confirmed (D-086).
  def disability_summary(profile)
    return "" unless profile.disability? || profile.disability_notes

    parts = profile.disability_types.map { |type| t("worker_profiles.disability_types.#{type}") }
    parts << t("panel.employees.show.rehabilitated") if profile.disability_rehabilitated
    [ parts.join(", "), profile.disability_notes ].compact_blank.join(". ")
  end

  def employment_detail_value(key, value)
    case key
    when *Employment::OPTIONS.keys then t("employments.options.#{key}.#{value}")
    when *Employment::DATE_DETAILS then l(Date.iso8601(value))
    when *Employment::CNPJ_DETAILS then Cnpj.format(value)
    when "supervisor_cpf" then Cpf.format(value)
    when "assurance_clause" then yes_no(value)
    when "union_base_month" then t("date.month_names")[value]
    else value
    end
  end

  # A known reason ("conversion") or the text typed (RN-04-054).
  def termination_reason(employment)
    t("employments.termination_reasons.#{employment.termination_reason}", default: employment.termination_reason)
  end

  def dependent_cpf(dependent)
    value = reveal_confirmed(dependent, :cpf, as: :text, section: :documents)
    value.presence && value != SensitiveData::HIDDEN && !impersonating? ? Cpf.format(value) : value.presence || "—"
  end

  def dependent_uses(dependent)
    uses = %i[irrf family_allowance incapable].select { |use| dependent.public_send(use) }
    uses.map { |use| t("panel.employees.show.uses.#{use}") }.join(", ").presence || "—"
  end

  # The firm's reading (D-652): the CPF as an access event, and the dependent without what
  # is about their health (P-03-18).
  def forward_cpf(user)
    value = reveal_confirmed(user, :cpf, as: :text, section: :documents)
    value.presence && value != SensitiveData::HIDDEN && !impersonating? ? Cpf.format(value) : value.presence || "—"
  end

  def forward_dependent_uses(dependent)
    uses = %i[irrf family_allowance].select { |use| dependent.public_send(use) }
    uses.map { |use| t("panel.employees.show.uses.#{use}") }.join(", ").presence || "—"
  end

  # "PIX (e-mail): ana@…" or "Banco 001 · agência 1234 · conta corrente 12345-6", the
  # number and the key shown only after the password (RN-02-052).
  def bank_account_summary(account)
    if account.pix?
      key = reveal_confirmed(account, :pix_key, as: :text, section: :pay)
      t("panel.employees.show.pix_summary", type: t("bank_accounts.pix_key_types.#{account.pix_key_type}"), key: key)
    else
      number = reveal_confirmed(account, :account_number, as: :bank_account, section: :pay)
      t("panel.employees.show.account_summary", bank: account.bank_code, branch: account.branch,
        type: t("bank_accounts.account_types.#{account.account_type}"), number: number)
    end
  end

  def custom_field_display(definition, value)
    return "—" if value.nil?

    case definition.field_type
    when "date" then l(Date.iso8601(value))
    when "boolean" then yes_no(value)
    when "number" then value.to_s.tr(".", ",")
    else value
    end
  end
end
