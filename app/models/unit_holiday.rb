# A unit's own day (RN-06-029, RN-11-020, D-242): a holiday or an optional day the HR
# adds, or a national holiday the team allows turning off (Good Friday, D-638) turned off
# in the unit. An optional day is a normal day unless the company dispenses the work,
# which comes with spec 11 (RN-11-022).
class UnitHoliday < ApplicationRecord
  audited

  KINDS = %w[holiday optional_day opt_out].freeze

  acts_as_tenant :company

  belongs_to :unit
  belongs_to :holiday, optional: true
  belongs_to :created_by, class_name: "User"

  enum :kind, KINDS.index_by(&:itself), validate: true

  normalizes :name, with: ->(name) { name.to_s.squish.presence }

  before_validation :take_holiday_date, if: :opt_out?

  validates :date, presence: true
  validates :date, uniqueness: { scope: :unit_id }
  validates :name, presence: true, length: { maximum: 120 }, unless: :opt_out?
  validates :holiday, presence: true, if: :opt_out?
  validate :holiday_allows_opt_out, if: -> { opt_out? && holiday }
  validate :unit_of_company

  private

  def take_holiday_date
    self.date = holiday&.date
    self.name = nil
  end

  def holiday_allows_opt_out
    errors.add(:holiday, :no_opt_out) unless holiday.level_national? && holiday.published? && holiday.unit_opt_out
  end

  def unit_of_company
    errors.add(:unit, :invalid) if unit && company_id && unit.company_id != company_id
  end
end
