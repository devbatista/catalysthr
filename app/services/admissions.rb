# The admission's rules around the process of spec 06 (spec 07, D-648). Read inside the
# company.
module Admissions
  module_function

  # The position's model, then the default of the employment kind, then the company's
  # default admission model (RN-07-013, P-07-04). Only active models start processes
  # (RN-06-002).
  def template_for(position_id:, kind:)
    own = Position.find_by(id: position_id)&.admission_template
    return own if own&.active?

    models = ProcessTemplate.admission.active
    models.where("? = ANY(default_employment_kinds)", kind).order(:name).first || models.find_by(is_default: true)
  end

  # The process of an admission (RN-07-012), dated from the start of the work: without the
  # company's accounting step, its items stay out (RN-07-003), and the documents the position
  # requires come in even when the model doesn't have them (RN-06-037).
  def start_process(template:, employment:, by:, starter:)
    Processes::Start.call(template: template, employment: employment, started_by: by, starter: starter,
      anchors: { "work_start" => employment.started_on },
      skip: (->(item) { accounting_item?(item) } unless employment.company.uses_accounting_step),
      extras: ->(items) { required_document_items(employment, items) })
  end

  def accounting_item?(item)
    item.forward? || item.stage == "accounting"
  end

  def required_document_items(employment, items)
    in_model = items.select(&:document?).map { |item| item.config["document_type_id"] }
    required = employment.effective_revision&.position&.required_document_type_ids.to_a - in_model
    DocumentType.usable.where(id: required).order(:name).map do |type|
      { kind: "document", title: type.name, responsible_role: "employee", required: true, stage: "documents",
        config: { "document_type_id" => type.id } }
    end
  end
  private_class_method :accounting_item?, :required_document_items
end
