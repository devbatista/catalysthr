module Processes
  # Starts a process from one of the company's active models (RN-06-050, D-091, D-641):
  # copies the model, keeps the items whose conditions hold for the employment
  # (RN-06-035, CA-06-002), resolves the people responsible (RN-06-020), dates each item
  # (RN-06-025, RN-06-026) and blocks those that wait for others (RN-06-040), ignoring the
  # dependencies on items left out (RN-06-042). An acknowledgement takes the PDF version in
  # use (P-06-17). The specs that use processes (07, 09) call it, and may leave items out or
  # add others (RN-07-003, RN-06-037). Read inside the company.
  module Start
    module_function

    # anchors: the reference dates of the kind, such as { "work_start" => date }; the
    # process's start is always today. started_by: the User; starter: their membership.
    # skip: which of the model's items stay out. extras: given the items kept, the attributes
    # of the ones to add, without a deadline.
    def call(template:, employment:, started_by:, starter:, anchors: {}, completion_mode: "confirm", skip: nil, extras: nil)
      raise ArgumentError, "only an active model starts a process" unless template.active?

      revision = employment.effective_revision
      ActiveRecord::Base.transaction do
        instance = ProcessInstance.create!(template: template, kind: template.kind, subject: employment, unit_id: revision&.unit_id,
          started_by: started_by, completion_mode: completion_mode, subject_snapshot: ProcessInstance.snapshot_of(employment),
          anchor_dates: anchor_dates(template.kind, instance_today(revision), anchors))
        responsibles = Responsibles.new(company: instance.company, employment: employment, kind: template.kind, starter: starter)
        source_items = template.items_with_materials.select { |item| applies?(item, employment, revision) && !skip&.call(item) }
        copies = source_items.each_with_index.to_h do |item, index|
          [ item.id, instance.items.create!(item_attributes(item, index, instance, responsibles)) ]
        end
        source_items.each do |item|
          (item.depends_on_item_ids & copies.keys).each do |id|
            copies.fetch(item.id).dependencies.create!(depends_on_item: copies.fetch(id))
          end
        end
        copies.each_value { |item| item.update!(status: "blocked") if item.dependencies.any? }
        added = extra_items(extras&.call(source_items), instance, responsibles, source_items.size)
        Events.record(instance, "started", by: started_by, template: template.name)
        Notices.assigned(copies.values.select(&:pending?) + added)
        instance
      end
    end

    # Every condition with values must hold; within one, any value (RN-06-035, P-06-11).
    def applies?(item, employment, revision)
      values = { "employment_kinds" => employment.kind, "position_ids" => revision&.position_id, "unit_ids" => revision&.unit_id,
        "allocation_client_ids" => revision&.allocation_client_id }
      item.conditions.all? { |key, allowed| allowed.blank? || allowed.include?(values[key]) }
    end

    def extra_items(attributes, instance, responsibles, count)
      Array(attributes).each_with_index.map do |item, index|
        assignment = responsibles.for(item.fetch(:responsible_role))
        instance.items.create!(item.merge(position: count + index + 1, status: "pending",
          responsible_membership_ids: assignment.membership_ids, responsible_fallback: assignment.fallback))
      end
    end

    def item_attributes(item, index, instance, responsibles)
      assignment = responsibles.for(item.responsible_role)
      config = item.config.dup
      config["material_id"] = item.material_in_use&.id if item.acknowledgement?
      { source_template_item_id: item.id, position: index + 1, kind: item.kind, stage: item.stage, title: item.title, instructions: item.instructions,
        required: item.required, status: "pending", responsible_role: item.responsible_role,
        responsible_membership_ids: assignment.membership_ids, responsible_fallback: assignment.fallback,
        due_anchor: item.due_anchor, due_offset_days: item.due_offset_days, due_business_days: item.due_business_days,
        due_on: Deadline.for(instance, item.due_anchor, item.due_offset_days, item.due_business_days), config: config }
    end

    def instance_today(revision)
      unit = revision && Unit.find_by(id: revision.unit_id)
      Time.find_zone(unit&.time_zone || "America/Sao_Paulo").today
    end

    # The process's own start is today; the other dates come from the spec that starts it.
    def anchor_dates(kind, today, anchors)
      anchors.to_h.transform_keys(&:to_s).transform_values { |date| date&.to_date&.iso8601 }.compact
        .merge("process_start" => today.iso8601, "request_opened" => today.iso8601)
        .slice(*ProcessTemplateItemDefinition::ANCHORS.fetch(kind))
    end
    private_class_method :applies?, :extra_items, :item_attributes, :instance_today, :anchor_dates
  end
end
