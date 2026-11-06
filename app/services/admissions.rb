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
      extras: ->(items) { required_document_items(employment, items) }).tap { |instance| hold_forwards(instance) }
  end

  # The forward waits for every required document, also the ones the position brought
  # (RN-07-070, P-06-13).
  def hold_forwards(instance)
    items = instance.items.reload.to_a
    documents = items.select { |item| item.document? && item.required }.map(&:id)
    items.select(&:forward?).each do |forward|
      missing = documents - forward.dependencies.pluck(:depends_on_item_id)
      missing.each { |id| forward.dependencies.create!(depends_on_item_id: id) }
      forward.update!(status: "blocked") if forward.pending? && documents.any?
    end
  end

  def accounting_item?(item)
    item.forward? || item.stage == "accounting"
  end

  def required_document_items(employment, items)
    in_model = items.select(&:document?).map { |item| item.config["document_type_id"] }
    required = employment.effective_revision&.position&.required_document_type_ids.to_a - in_model
    types = DocumentType.usable.where(id: required).order(:name).to_a
    # The CLT's ASO even when the model doesn't have it or the company turned the type off
    # (RN-07-060, D-648).
    aso = Aso.type if employment.clt?
    types |= [ aso ] if aso && !in_model.include?(aso.id)
    types.map do |type|
      # The employee doesn't send health documents (spec 03, section 4.5).
      { kind: "document", title: type.name, responsible_role: type.category == "health" ? "hr" : "employee", required: true,
        stage: "documents", config: { "document_type_id" => type.id } }
    end
  end
  private_class_method :hold_forwards, :accounting_item?, :required_document_items

  # The PDFs generated live only in the process (D-650).
  def delete_generated(employment)
    return if Simulation.active?

    GeneratedDocument.where(employment_id: employment.id).find_each { |generated| generated.file.purge if generated.file.attached? }
  end
end
