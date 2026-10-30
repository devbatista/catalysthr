# The models of process on the admin's, the partner's and the company's screens (spec 06,
# D-639).
module ProcessTemplatesHelper
  STATUS_PILLS = { "draft" => "pill-warn", "active" => "pill-ok", "archived" => "pill-mute" }.freeze

  def template_status_pill(template)
    tag.span(t("process_templates.statuses.#{template.status}"), class: "pill #{STATUS_PILLS.fetch(template.status)}")
  end

  # Where an adoptable model comes from: the library or the partner (P-06-02).
  def template_origin(template)
    template.partner_id ? template.partner.name : t("process_templates.library")
  end

  # "3 dias úteis antes da data de início do trabalho", "No dia de início do processo" or
  # "Sem prazo" (RN-06-025).
  def item_deadline(item)
    return t("process_templates.items.no_deadline") unless item.deadline?

    anchor = t("process_templates.anchors_relative.#{item.due_anchor}")
    days = item.due_offset_days.to_i
    return t("process_templates.items.on_anchor", anchor: anchor) if days.zero?

    kind = item.due_business_days ? "business" : "calendar"
    t("process_templates.items.deadline_#{days.negative? ? "before" : "after"}",
      days: t("process_templates.items.days_#{kind}", count: days.abs), anchor: anchor)
  end

  # "CLT, Estágio · Unidade: Caxias" or "Todos" (RN-06-035).
  def item_conditions(item, names)
    parts = item.conditions.map do |key, values|
      labels = key == "employment_kinds" ? values.map { |kind| t("employments.kinds.#{kind}") } : values.map { |id| names[id] || "—" }
      "#{t("process_templates.conditions.#{key}")}: #{labels.join(", ")}"
    end
    parts.presence&.join(" · ") || t("process_templates.items.everyone")
  end

  # The names of the company's positions, units and clients the conditions point to.
  def condition_names(template)
    return {} unless template.company_level?

    [ Position, Unit, AllocationClient ].flat_map { |model| model.pluck(:id, :name) }.to_h
  end

  def responsible_roles(template)
    roles = ProcessTemplateItemDefinition::ROLES
    # The client's managers only in a company that uses allocation clients (P-06-21).
    roles -= %w[client_manager] if template.company_level? && !Current.company&.uses_allocation_clients
    roles.map { |role| [ t("process_templates.roles.#{role}"), role ] }
  end
end
