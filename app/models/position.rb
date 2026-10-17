# A position of the company, valid in every unit (RN-04-030, D-204), with its CBO checked
# against the official table (RN-04-031, P-04-13) and an optional salary range in cents.
# A salary out of the range is not blocked: it asks for a justification on the
# employment's revision (RN-04-032, spec 04's block 4c).
class Position < ApplicationRecord
  audited

  STATUSES = %w[active inactive].freeze

  acts_as_tenant :company

  enum :status, STATUSES.index_by(&:itself), validate: true

  normalizes :cbo_code, with: ->(code) { code.to_s.gsub(/\D/, "") }

  scope :ordered, -> { order(:name) }

  validates :name, presence: true, length: { maximum: 120 }
  validates :cbo_code, presence: true
  validates :salary_min_cents, :salary_max_cents, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validate :official_cbo
  validate :salary_range

  def audit_company_id
    company_id
  end

  def cbo_occupation
    CboOccupation.find_by(code: cbo_code)
  end

  def within_range?(cents)
    (salary_min_cents.nil? || cents >= salary_min_cents) && (salary_max_cents.nil? || cents <= salary_max_cents)
  end

  # "R$ 2.000,00 a R$ 3.500,00", "a partir de R$ 2.000,00", "até R$ 3.500,00" or "—".
  def salary_range_text
    min, max = [ salary_min_cents, salary_max_cents ].map { |cents| cents && "R$ #{MoneyCents.format(cents)}" }
    return I18n.t("positions.range.between", min: min, max: max) if min && max
    return I18n.t("positions.range.from", min: min) if min
    return I18n.t("positions.range.up_to", max: max) if max

    "—"
  end

  private

  # Only an active code is accepted when the CBO changes; a position keeps a code that
  # later left the table.
  def official_cbo
    return if cbo_code.blank? || !cbo_code_changed?

    errors.add(:cbo_code, :not_official) unless CboOccupation.active.exists?(code: cbo_code)
  end

  def salary_range
    return if salary_min_cents.nil? || salary_max_cents.nil?

    errors.add(:salary_max_cents, :below_minimum) if salary_max_cents < salary_min_cents
  end
end
