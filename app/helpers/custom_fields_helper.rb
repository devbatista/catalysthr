module CustomFieldsHelper
  # "Obrigatório · visível ao colaborador" or "—".
  def custom_field_rules(field)
    rules = %i[required visible_to_employee editable_by_employee].select { |rule| field.public_send(rule) }
    rules.map { |rule| t("panel.custom_fields.rules.#{rule}") }.join(" · ").presence || "—"
  end
end
