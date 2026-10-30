# What every item of a model of process has, at any level (spec 06, RN-06-010 to
# RN-06-042, D-639): kind, responsible role, deadline, conditions, dependencies and the
# kind's own settings.
module ProcessTemplateItemDefinition
  extend ActiveSupport::Concern

  KINDS = %w[task document form acknowledgement forward approval].freeze
  # The kinds the editor offers: the acknowledgement's material comes with block 06b-2 and
  # the document, with spec 08's document types (D-639).
  EDITOR_KINDS = %w[task form forward approval].freeze
  ROLES = %w[employee hr manager upper_manager accountant client_manager initiator].freeze
  # The dates a deadline counts from, by the model's kind (RN-06-025, P-06-07).
  ANCHORS = {
    "admission" => %w[process_start work_start],
    "onboarding" => %w[work_start],
    "offboarding" => %w[process_start termination],
    "request_flow" => %w[request_opened request_date]
  }.freeze
  # The record's groups a form fills (RN-04-041, RN-06-030, D-639).
  FORM_GROUPS = %w[identification birth documents address foreigner disability contact emergency_contacts dependents
    bank_account].freeze
  FREE_FIELDS_LIMIT = 20
  MAX_OFFSET_DAYS = 365
  # Conditions by employment kind, position, unit and allocation client (RN-06-035,
  # P-06-22). Positions, units and clients are the company's, so a library's or a partner's
  # model has only the employment kind; the company adds the others after adopting it.
  COMPANY_CONDITIONS = %w[position_ids unit_ids allocation_client_ids].freeze
  CONDITIONS = (%w[employment_kinds] + COMPANY_CONDITIONS).freeze

  included do
    self.table_name = "process_template_items"

    audited

    enum :kind, KINDS.index_by(&:itself), validate: true

    normalizes :title, with: ->(title) { title.to_s.squish.presence }
    normalizes :instructions, with: ->(text) { text.to_s.strip.presence }

    before_validation :clean_conditions_and_config

    validates :title, presence: true, length: { maximum: 160 }
    validates :instructions, length: { maximum: 4000 }
    validates :responsible_role, inclusion: { in: ROLES }
    validates :position, presence: true
    validate :deadline
    validate :conditions_allowed
    validate :config_of_kind
    validate :dependencies
  end

  def anchors
    ANCHORS.fetch(template&.kind, [])
  end

  def deadline?
    due_anchor.present?
  end

  def depends_on
    template.items.select { |item| depends_on_item_ids.include?(item.id) }
  end

  # The attributes an adopted copy takes (D-232); the dependencies are mapped afterwards.
  def copy_attributes
    attributes.slice(*%w[position kind title instructions required responsible_role due_anchor due_offset_days
      due_business_days conditions config])
  end

  private

  def clean_conditions_and_config
    self.conditions = CONDITIONS.to_h { |key| [ key, Array(conditions&.dig(key)).map(&:to_s).compact_blank.uniq ] }
      .select { |_key, values| values.any? }
    self.depends_on_item_ids = Array(depends_on_item_ids).compact_blank.uniq
    self.config = case kind
    when "form"
      { "groups" => Array(config&.dig("groups")).map(&:to_s) & FORM_GROUPS,
        "custom_field_keys" => Array(config&.dig("custom_field_keys")).map(&:to_s).compact_blank.uniq,
        "free_fields" => Array(config&.dig("free_fields")).map { |label| label.to_s.squish }.compact_blank.uniq }
    when "forward"
      { "validated_documents" => ActiveModel::Type::Boolean.new.cast(config&.dig("validated_documents")) || false,
        "record" => ActiveModel::Type::Boolean.new.cast(config&.dig("record")) || false }
    else
      config.presence || {}
    end
  end

  def deadline
    if due_anchor.blank?
      self.due_offset_days = nil
      self.due_business_days = false
    elsif !anchors.include?(due_anchor)
      errors.add(:due_anchor, :inclusion)
    elsif !due_offset_days.is_a?(Integer) || due_offset_days.abs > MAX_OFFSET_DAYS
      errors.add(:due_offset_days, :invalid, max: MAX_OFFSET_DAYS)
    end
  end

  def conditions_allowed
    if (conditions["employment_kinds"] || []).difference(Employment::KINDS).any?
      errors.add(:conditions, :invalid)
    elsif !template&.company_level? && conditions.keys.intersect?(COMPANY_CONDITIONS)
      errors.add(:conditions, :company_only)
    elsif template&.company_level? && !company_conditions_exist?
      errors.add(:conditions, :invalid)
    end
  end

  # Each id must be one of the company's; the tenant scopes the lookups.
  def company_conditions_exist?
    { "position_ids" => Position, "unit_ids" => Unit, "allocation_client_ids" => AllocationClient }.all? do |key, model|
      ids = conditions[key] || []
      ids.empty? || model.where(id: ids).count == ids.size
    end
  end

  def config_of_kind
    case kind
    when "form"
      chosen = config["groups"].any? || config["custom_field_keys"].any? || config["free_fields"].any?
      errors.add(:config, :form_empty) unless chosen
      errors.add(:config, :too_many_free_fields, count: FREE_FIELDS_LIMIT) if config["free_fields"].size > FREE_FIELDS_LIMIT
      errors.add(:config, :custom_fields_company_only) if config["custom_field_keys"].any? && !template&.company_level?
      errors.add(:config, :invalid) if template&.company_level? && !custom_fields_exist?
    when "forward"
      errors.add(:config, :forward_empty) unless config["validated_documents"] || config["record"]
    end
  end

  def custom_fields_exist?
    keys = config["custom_field_keys"]
    keys.empty? || CustomFieldDefinition.where(key: keys).count == keys.size
  end

  # An item depends only on other items of the same model, never in a cycle (RN-06-040,
  # RN-06-041, CA-06-008).
  def dependencies
    return if depends_on_item_ids.empty?

    siblings = template.items.reject { |item| item.id == id }.index_by(&:id)
    return errors.add(:depends_on_item_ids, :invalid) unless (depends_on_item_ids - siblings.keys).empty?

    errors.add(:depends_on_item_ids, :cycle) if id && reaches_self?(siblings)
  end

  def reaches_self?(siblings)
    seen = Set.new
    pending = depends_on_item_ids.dup
    while (current = pending.shift)
      return true if current == id
      next unless seen.add?(current)

      pending.concat(siblings[current]&.depends_on_item_ids || [])
    end
    false
  end
end
