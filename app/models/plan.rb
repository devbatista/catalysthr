# A plan of the CatalystHR, for partners or for direct companies (spec 19, RN-19-010,
# D-480, D-122), registered by the superadmin and the finance team. Prices, limits and
# quotas live in versions that never change (RN-19-014, D-611): a new price is a new
# version, valid for new contracts from its date. An archived plan is no longer offered.
class Plan < ApplicationRecord
  audited

  KINDS = %w[partner direct].freeze
  STATUSES = %w[active archived].freeze

  # Versions are saved on their own, never through the plan (Admin::PlansController).
  has_many :plan_versions, -> { order(:version) }, class_name: "PlanVersion", inverse_of: :plan, dependent: :restrict_with_exception,
    validate: false, autosave: false

  enum :kind, KINDS.index_by(&:itself), validate: true
  enum :status, STATUSES.index_by(&:itself), validate: true

  normalizes :name, with: ->(name) { name.to_s.squish }

  scope :ordered, -> { order(:kind, :name) }

  validates :name, presence: true, length: { maximum: 120 }
  validate :unique_name

  # The version in force on a date: the latest that started by then and, between versions
  # of the same date, the one registered last (D-611).
  def version_on(date = Date.current)
    plan_versions.select { |version| version.valid_from <= date }.max_by { |version| [ version.valid_from, version.version ] }
  end

  # The latest version registered, the base for the next one.
  def latest_version
    plan_versions.max_by(&:version)
  end

  private

  def unique_name
    return if name.blank?

    taken = Plan.where(kind: kind).where("lower(name) = ?", name.downcase).where.not(id: id).exists?
    errors.add(:name, :taken) if taken
  end
end
