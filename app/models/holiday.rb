# A holiday kept by the CatalystHR team for every company: national, state or city
# (RN-06-029, RN-11-020, D-242, D-336). National ones come from BrasilAPI once a year and
# count only after the team publishes them (P-11-06, D-638); the ones the team registers
# by hand are born published. Not company-owned: a company's own days are UnitHoliday.
class Holiday < ApplicationRecord
  audited

  LEVELS = %w[national state city].freeze
  STATUSES = %w[pending published rejected].freeze
  SOURCES = %w[manual brasil_api].freeze
  IBGE_CITY_CODE_FORMAT = /\A\d{7}\z/

  belongs_to :reviewed_by, class_name: "User", optional: true

  # Prefixed: a "state" level would clash with the state column.
  enum :level, LEVELS.index_by(&:itself), prefix: true, validate: true
  enum :status, STATUSES.index_by(&:itself), validate: true
  enum :source, SOURCES.index_by(&:itself), validate: true

  normalizes :state, with: ->(state) { state.to_s.strip.upcase.presence }
  normalizes :ibge_city_code, with: ->(code) { code.to_s.gsub(/\D/, "").presence }
  normalizes :name, :city_name, with: ->(name) { name.to_s.squish.presence }

  scope :ordered, -> { order(:date, :level, :state, :city_name) }
  scope :in_year, ->(year) { where(date: Date.new(year).all_year) }

  before_validation :clear_place

  validates :name, presence: true, length: { maximum: 120 }
  validates :date, presence: true
  validates :state, inclusion: { in: Unit::STATES }, unless: :level_national?
  validates :ibge_city_code, format: { with: IBGE_CITY_CODE_FORMAT }, if: :level_city?
  validates :city_name, presence: true, length: { maximum: 120 }, if: :level_city?
  validates :date, uniqueness: { scope: %i[level state ibge_city_code] }
  validate :opt_out_only_national

  # The holidays that reach a place: the national ones, the state's and the city's. A
  # unit without the state or the IBGE code gets only what it can be matched to.
  def self.reaching(state:, ibge_city_code:)
    relation = level_national
    relation = relation.or(level_state.where(state: state)) if state.present?
    relation = relation.or(level_city.where(ibge_city_code: ibge_city_code)) if ibge_city_code.present?
    relation
  end

  # The team publishes or rejects a holiday, recording who did it (P-11-06).
  def review!(status, by:, unit_opt_out: self.unit_opt_out)
    update!(status: status, unit_opt_out: unit_opt_out, reviewed_by: by, reviewed_at: Time.current)
  end

  private

  def clear_place
    self.state = nil if level_national?
    self.ibge_city_code = self.city_name = nil unless level_city?
  end

  # Only a national holiday is turned off in a unit, as Good Friday (D-638).
  def opt_out_only_national
    errors.add(:unit_opt_out, :only_national) if unit_opt_out && !level_national?
  end
end
