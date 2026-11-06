# The entry of a person in the company (spec 07, P-07-18): links the employment, the process
# made from the admission's model, the eSocial and the ASO. Its status is the process's
# (section 5). The steps don't block the items, the dependencies do (RN-07-002); the step
# shown is the first with a required item pending.
class Admission < ApplicationRecord
  SOURCES = %w[manual recruitment import].freeze
  ESOCIAL_STATUSES = %w[not_applicable not_sent sent accepted rejected].freeze
  ASO_STATUSES = %w[missing fit unfit].freeze
  # The bar's steps (D-250). The AI's has no items: it's the system's (RN-07-004).
  STEPS = %w[registration documents ai hr_review accounting conclusion].freeze
  CANCEL_REASONS = %w[withdrew aso_unfit company_withdrew other].freeze

  acts_as_tenant :company

  # Fit or unfit is health data (D-086, D-651), and so is a cancellation for an unfit ASO.
  audited sensitive: %i[aso_status aso_exam_on cancel_reason cancel_note]

  belongs_to :employment
  belongs_to :process_instance
  belongs_to :invite_released_by, class_name: "User", optional: true
  belongs_to :completed_by, class_name: "User", optional: true

  enum :source, SOURCES.index_by(&:itself), validate: true, prefix: :from
  enum :esocial_status, ESOCIAL_STATUSES.index_by(&:itself), validate: true, prefix: :esocial

  encrypts :aso_status, :cancel_reason, :cancel_note

  validates :aso_status, inclusion: { in: ASO_STATUSES }, allow_nil: true

  # Open and without the invitation released: who the portal's invitation must leave out
  # (D-252, D-648).
  scope :in_status, ->(status) { joins(:process_instance).where(process_instances: { status: status }) }
  scope :awaiting_release, -> { in_status("open").where(invite_released_at: nil) }
  # Started with the admission open, or past the start and held: the serious alert of the
  # activation, until the admission ends (RN-07-085, D-653). Says nothing about the ASO.
  scope :needing_attention, lambda {
    in_status("open").joins(:employment).where("employments.status IN ('active', 'on_leave') OR " \
      "(employments.status = 'pending' AND employments.started_on <= ?)", Date.current)
  }

  delegate :open?, :completed?, :cancelled?, :status, to: :process_instance
  delegate :worker_profile, :started_on, to: :employment

  def self.for_profile(profile)
    where(employment_id: Employment.where(worker_profile_id: profile.id).select(:id))
  end

  def audit_company_id
    company_id
  end

  def aso_status
    super || "missing"
  end

  def aso_fit?
    aso_status == "fit"
  end

  def aso_unfit?
    aso_status == "unfit"
  end

  # An exam after the start: the law asks for it before (CLT art. 168, D-651). It doesn't
  # block, because it already happened; the screen warns.
  def aso_late?
    aso_exam_on.present? && aso_exam_on > started_on
  end

  def released?
    invite_released_at.present?
  end

  # Without the accounting step, it doesn't show (RN-07-003, CA-07-011).
  def steps
    company.uses_accounting_step ? STEPS : STEPS - %w[accounting]
  end

  # The first step with a required item pending, or the conclusion (RN-07-002).
  def current_step
    pending = process_instance.items.select { |item| item.required && !item.resolved? }.map(&:stage)
    steps.find { |step| pending.include?(step) } || "conclusion"
  end

  # "Esta pessoa já tem vínculo": another open employment in the company doesn't block the
  # admission (RN-07-014, D-205).
  def other_open_employment?
    Employment.open.where(worker_profile_id: employment.worker_profile_id).where.not(id: employment_id).exists?
  end
end
