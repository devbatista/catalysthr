# The models of process on the admin's, the partner's and the company's screens (spec 06,
# D-639).
module ProcessTemplatesHelper
  STATUS_PILLS = { "draft" => "pill-warn", "active" => "pill-ok", "archived" => "pill-mute" }.freeze
  SCAN_PILLS = { "scanning" => "pill-warn", "clean" => "pill-ok", "infected" => "pill-bad" }.freeze

  def template_status_pill(template)
    tag.span(t("process_templates.statuses.#{template.status}"), class: "pill #{STATUS_PILLS.fetch(template.status)}")
  end

  # Where an adoptable model comes from: the library or the partner (P-06-02).
  def template_origin(template)
    template.partner_id ? template.partner.name : t("process_templates.library")
  end

  # The virus scan of a version of the PDF (P-05-30, D-640).
  def material_scan_pill(material)
    tag.span(t("process_templates.materials.scan.#{material.scan_status}"), class: "pill #{SCAN_PILLS.fetch(material.scan_status)}")
  end

  # The PDF of an acknowledgement item: the version in use, with its link, and the newest
  # one while it is scanning or once refused (RN-06-060, D-640).
  def item_material(item)
    in_use = item.material_in_use
    latest = item.latest_material
    parts = [ in_use ? material_link(item.template, in_use) : tag.span(t("process_templates.materials.none"), class: "pill pill-warn") ]
    if latest && latest != in_use
      parts << tag.span(t("process_templates.materials.latest.#{latest.scan_status}", version: latest.version),
        class: "pill #{SCAN_PILLS.fetch(latest.scan_status)}")
    end
    tag.span(safe_join(parts), class: "mt-1 flex flex-wrap items-center gap-2 text-xs")
  end

  # Opens the PDF in a new tab; only a clean version has it (D-640).
  def material_link(template, material, label: t("process_templates.materials.in_use", version: material.version))
    link_to(label, template_route(:template_material, template, material_id: material.id), class: "link-button", target: "_blank",
      rel: "noopener")
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
