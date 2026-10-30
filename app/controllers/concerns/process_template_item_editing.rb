# The items of a model of process, at the three levels (spec 06, RN-06-010 to RN-06-042,
# D-639): each one in its own form, with the kind chosen before (the form shows only that
# kind's settings), and moved up or down in the list. An archived model is read only.
# Each controller says where its models come from (template_scope) and its routes' prefix.
module ProcessTemplateItemEditing
  extend ActiveSupport::Concern
  include ProcessTemplateRoutes

  included do
    before_action :load_template
    before_action :load_item, only: %i[edit update destroy move]
  end

  def new
    authorize! :update, @template
    kind = params[:kind].presence_in(ProcessTemplateItemDefinition::EDITOR_KINDS) || "task"
    @item = @template.items.build(kind: kind, responsible_role: "hr", required: true)
    render "shared/process_templates/items/new"
  end

  def create
    authorize! :update, @template
    kind = params.dig(:item, :kind).presence_in(ProcessTemplateItemDefinition::EDITOR_KINDS)
    @item = @template.items.build(kind: kind, position: (@template.items.maximum(:position) || 0) + 1)
    @item.assign_attributes(item_params)
    assign_material

    if @item.save(context: %i[create editor_create])
      redirect_to template_route(:template, @template, anchor: "items"), notice: t("process_templates.items.created")
    else
      render "shared/process_templates/items/new", status: :unprocessable_content
    end
  end

  def edit
    authorize! :update, @template
    render "shared/process_templates/items/edit"
  end

  def update
    authorize! :update, @template
    @item.assign_attributes(item_params)
    assign_material
    if @item.save
      redirect_to template_route(:template, @template, anchor: "items"), notice: t("process_templates.items.updated")
    else
      render "shared/process_templates/items/edit", status: :unprocessable_content
    end
  end

  # The items that depended on it lose the dependency (RN-06-040).
  def destroy
    authorize! :update, @template
    @item.transaction do
      @template.items.where("? = ANY(depends_on_item_ids)", @item.id).find_each do |item|
        item.update!(depends_on_item_ids: item.depends_on_item_ids - [ @item.id ])
      end
      @item.destroy!
    end
    redirect_to template_route(:template, @template, anchor: "items"), notice: t("process_templates.items.destroyed")
  end

  # Swaps the item with the one above or below it.
  def move
    authorize! :update, @template
    items = @template.items.to_a
    index = items.index(@item)
    neighbor = items[params[:direction] == "up" ? index - 1 : index + 1] if index
    if neighbor && (params[:direction] == "down" || index.positive?)
      @item.transaction do
        position = @item.position
        @item.update!(position: neighbor.position)
        neighbor.update!(position: position)
      end
    end
    redirect_to template_route(:template, @template, anchor: "items")
  end

  private

  # Out of the person's reach answers 404 (RN-03-006); an archived model is read only.
  def load_template
    @template = template_scope.accessible_by(current_ability, :read).find(params[:process_template_id])
    return if @template.editable?

    redirect_to template_route(:template, @template), alert: t("process_templates.archived_read_only")
  end

  def load_item
    @item = @template.items.find(params[:id])
  end

  # The acknowledgement's PDF comes apart from the item's fields; each one sent is a new
  # version (RN-06-060, D-640).
  def assign_material
    file = params.dig(:item, :material_file)
    @item.material_file = file if file.is_a?(ActionDispatch::Http::UploadedFile)
    @item.material_uploaded_by = current_user
  end

  # The deadline comes as days before or after the date (RN-06-025); the free fields, one
  # per line.
  def item_params
    attributes = params.expect(item: [ :title, :instructions, :required, :responsible_role, :due_anchor, :due_offset_days,
      :due_direction, :due_business_days, :free_fields,
      { conditions: [ employment_kinds: [], position_ids: [], unit_ids: [], allocation_client_ids: [] ],
        config: [ :validated_documents, :record, { groups: [], custom_field_keys: [] } ],
        depends_on_item_ids: [] } ])
    direction = attributes.delete(:due_direction)
    if attributes[:due_offset_days].present?
      days = attributes[:due_offset_days].to_i.abs
      attributes[:due_offset_days] = direction == "before" ? -days : days
    end
    free_fields = attributes.delete(:free_fields)
    if @item.form?
      attributes[:config] = (attributes[:config] || {}).to_h.merge("free_fields" => free_fields.to_s.lines.map(&:strip))
    end
    attributes[:conditions] = attributes[:conditions].to_h if attributes.key?(:conditions)
    attributes
  end
end
