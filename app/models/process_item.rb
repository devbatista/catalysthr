# An item of a process (spec 06, RN-06-010 to RN-06-066, D-641): the copy of a model's
# item, already with the people responsible, the date and whether it is blocked. The HR
# may change it while the process is open, and each change goes to the history
# (RN-06-051).
class ProcessItem < ApplicationRecord
  KINDS = ProcessTemplateItemDefinition::KINDS
  STATUSES = %w[blocked pending submitted correction_requested done skipped approved rejected sent received].freeze
  # Done, skipped, approved or received count as resolved for the dependencies and the end
  # (RN-06-040, RN-06-052). A rejection is not: the spec that uses the process decides.
  RESOLVED = %w[done skipped approved received].freeze
  OPEN = %w[blocked pending submitted correction_requested sent].freeze
  # The kinds completed in the panel in this block; the others come with specs 07 and 16
  # (D-641).
  PANEL_KINDS = %w[task approval forward].freeze
  # The kinds the HR adds to a process under way (RN-06-051).
  ADDABLE_KINDS = PANEL_KINDS
  RECEIPT_MAX_SIZE = 10.megabytes

  acts_as_tenant :company

  audited

  belongs_to :instance, class_name: "ProcessInstance", foreign_key: :process_instance_id, inverse_of: :items
  belongs_to :source_template_item, class_name: "ProcessTemplateItem", optional: true
  belongs_to :completed_by, class_name: "User", optional: true
  has_many :dependencies, class_name: "ProcessItemDependency", foreign_key: :item_id, inverse_of: :item, dependent: :delete_all
  has_many :dependents, class_name: "ProcessItemDependency", foreign_key: :depends_on_item_id, inverse_of: :depends_on_item,
    dependent: :delete_all
  has_many :depends_on, through: :dependencies, source: :depends_on_item
  has_one :form_response, class_name: "ProcessFormResponse", foreign_key: :process_item_id, inverse_of: :item, dependent: :destroy
  # The receipt of a forward recorded by the HR (RN-06-066).
  has_one_attached :forward_receipt

  enum :kind, KINDS.index_by(&:itself), validate: true
  enum :status, STATUSES.index_by(&:itself), validate: true

  normalizes :title, with: ->(title) { title.to_s.squish.presence }
  normalizes :instructions, with: ->(text) { text.to_s.strip.presence }
  normalizes :skipped_reason, with: ->(text) { text.to_s.strip.presence }

  # An item the HR adds to an admission takes its step from the kind (RN-07-001).
  before_validation -> { self.stage ||= ProcessTemplateItemDefinition.default_stage(kind) }, if: -> { instance&.admission? }

  validates :title, presence: true, length: { maximum: 160 }
  validates :instructions, length: { maximum: 4000 }
  validates :responsible_role, inclusion: { in: ProcessTemplateItemDefinition::ROLES }
  validates :position, presence: true
  validates :skipped_reason, length: { maximum: 2000 }
  validate :skip_reason_when_required

  def audit_company_id
    company_id
  end

  def resolved?
    status.in?(RESOLVED)
  end

  def open?
    status.in?(OPEN)
  end

  def overdue?(today = instance.today)
    open? && due_on.present? && due_on < today
  end

  def panel_kind?
    kind.in?(PANEL_KINDS)
  end

  def responsibles
    Membership.where(id: responsible_membership_ids)
  end

  def responsible?(membership)
    membership.present? && responsible_membership_ids.include?(membership.id)
  end

  # The version of the acknowledgement's PDF chosen at the start (P-06-17, D-640).
  def material
    ProcessTemplateMaterial.find_by(id: config["material_id"]) if acknowledgement?
  end

  private

  # A required item is skipped only with a reason (RN-06-052, P-06-15).
  def skip_reason_when_required
    errors.add(:skipped_reason, :blank) if skipped? && required && skipped_reason.blank?
  end
end
