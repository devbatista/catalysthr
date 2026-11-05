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

  acts_as_tenant :company

  audited

  belongs_to :employment
  belongs_to :process_instance
  belongs_to :invite_released_by, class_name: "User", optional: true
  belongs_to :completed_by, class_name: "User", optional: true

  enum :source, SOURCES.index_by(&:itself), validate: true, prefix: :from
  enum :esocial_status, ESOCIAL_STATUSES.index_by(&:itself), validate: true, prefix: :esocial
  enum :aso_status, ASO_STATUSES.index_by(&:itself), validate: true, prefix: :aso

  # Open and without the invitation released: who the portal's invitation must leave out
  # (D-252, D-648).
  scope :in_status, ->(status) { joins(:process_instance).where(process_instances: { status: status }) }
  scope :awaiting_release, -> { in_status("open").where(invite_released_at: nil) }

  delegate :open?, :completed?, :cancelled?, :status, to: :process_instance
  delegate :worker_profile, :started_on, to: :employment

  def self.for_profile(profile)
    where(employment_id: Employment.where(worker_profile_id: profile.id).select(:id))
  end

  def audit_company_id
    company_id
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
