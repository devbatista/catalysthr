# A process under way (spec 06, RN-06-050 to RN-06-053, D-091, D-641): a copy of one of
# the company's models for a subject, such as an employment. Changes to the model never
# reach it. It ends when the HR confirms, once every required item is resolved, unless
# the spec that uses it chooses the automatic end (RN-06-053).
class ProcessInstance < ApplicationRecord
  STATUSES = %w[open completed cancelled].freeze
  COMPLETION_MODES = %w[confirm automatic].freeze
  # The module the HR analyst and the consultant need for each kind (spec 03, D-641).
  MODULES = { "admission" => "admissao", "onboarding" => "admissao", "offboarding" => "solicitacoes",
    "request_flow" => "solicitacoes" }.freeze
  # The employment's data kept at the start, to warn when they change (RN-06-036).
  SNAPSHOT_KEYS = %w[employment_kind position_id unit_id department_id allocation_client_id].freeze

  acts_as_tenant :company

  audited

  belongs_to :template, class_name: "ProcessTemplate", foreign_key: :process_template_id, optional: true
  belongs_to :subject, polymorphic: true
  belongs_to :unit, optional: true
  belongs_to :started_by, class_name: "User"
  belongs_to :completed_by, class_name: "User", optional: true
  belongs_to :cancelled_by, class_name: "User", optional: true
  has_many :items, -> { order(:position) }, class_name: "ProcessItem", inverse_of: :instance, dependent: nil
  has_many :events, -> { order(:created_at, :id) }, class_name: "ProcessEvent", inverse_of: :instance, dependent: nil

  enum :kind, ProcessTemplateDefinition::KINDS.index_by(&:itself), validate: true
  enum :status, STATUSES.index_by(&:itself), validate: true
  enum :completion_mode, COMPLETION_MODES.index_by(&:itself), validate: true, prefix: :completes

  normalizes :cancel_reason, with: ->(text) { text.to_s.strip.presence }

  validates :cancel_reason, presence: true, length: { maximum: 2000 }, if: :cancelled?

  def audit_company_id
    company_id
  end

  def employment
    subject if subject_type == "Employment"
  end

  # The anchor dates, typed (RN-06-025).
  def anchor_date(name)
    value = anchor_dates[name.to_s]
    value && Date.iso8601(value)
  end

  # Today where the person works (the unit's time zone).
  def today
    Time.find_zone(unit&.time_zone || "America/Sao_Paulo").today
  end

  def calendar
    @calendar ||= Holidays::Calendar.new(unit)
  end

  def required_resolved?
    items.select(&:required).all?(&:resolved?)
  end

  def ready_to_complete?
    open? && required_resolved?
  end

  # The employment's data that changed since the start (RN-06-036, P-06-12).
  def subject_changes
    return [] unless employment

    current = self.class.snapshot_of(employment)
    SNAPSHOT_KEYS.reject { |key| current[key] == subject_snapshot[key] }
  end

  def responsible_alert?
    open? && items.any? { |item| item.open? && item.responsible_fallback }
  end

  def self.snapshot_of(employment)
    revision = employment.effective_revision
    { "employment_kind" => employment.kind, "position_id" => revision&.position_id, "unit_id" => revision&.unit_id,
      "department_id" => revision&.department_id, "allocation_client_id" => revision&.allocation_client_id }
  end
end
