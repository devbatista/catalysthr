# What every model of process has, at any level (spec 06, RN-06-001, RN-06-002, D-639):
# the company's (ProcessTemplate) and the library's or the partner's
# (SharedProcessTemplate) read the same table.
module ProcessTemplateDefinition
  extend ActiveSupport::Concern

  KINDS = %w[admission onboarding offboarding request_flow].freeze
  STATUSES = %w[draft active archived].freeze

  included do
    self.table_name = "process_templates"

    audited

    enum :kind, KINDS.index_by(&:itself), validate: true
    enum :status, STATUSES.index_by(&:itself), validate: true

    normalizes :name, with: ->(name) { name.to_s.squish.presence }
    normalizes :description, with: ->(text) { text.to_s.strip.presence }

    scope :ordered, -> { in_order_of(:status, STATUSES).order(:kind, :name) }

    validates :name, presence: true, length: { maximum: 120 }
    validates :description, length: { maximum: 2000 }
    validate :kind_unchanged, on: :update
    validate :materials_ready, if: -> { will_save_change_to_status?(to: "active") }
  end

  # Only active models are adopted or start processes; archiving does not touch the
  # processes already started (RN-06-002, D-091).
  def activate!
    update!(status: "active")
  end

  def archive!
    update!(status: "archived", is_default: false, default_employment_kinds: [])
  end

  def editable?
    !archived?
  end

  # The items with the PDFs and their scans, for the screens and the activation.
  def items_with_materials
    items.includes(materials: { file_attachment: { blob: :file_scan } })
  end

  private

  # The items' deadlines depend on the kind's dates (RN-06-025).
  def kind_unchanged
    errors.add(:kind, :unchanged) if kind_changed?
  end

  # Every acknowledgement item needs a clean version of its PDF (RN-06-060, D-640).
  def materials_ready
    pending = items_with_materials.select { |item| item.acknowledgement? && item.material_in_use.nil? }
    errors.add(:base, :materials_not_ready, titles: pending.map(&:title).to_sentence) if pending.any?
  end
end
