# The employment's conditions from a date on (RN-04-060 to RN-04-064, P-04-02, D-207):
# position and CBO, salary, unit and department, weekly hours, the reason and, for a
# monthly salary out of the position's range, the justification (RN-04-032, D-603).
#
# A future revision may be edited or deleted until its date; one in force never changes,
# and is corrected by a new revision with the reason "correction", which may share its
# date and then prevails (RN-04-061, D-603). The salary is sensitive (D-086): encrypted,
# in cents, out of the versions.
#
# Dates are compared with today in Brasília. The allocation client is optional, and
# changing it is a new revision (RN-04-092, RN-04-093). The work schedule comes with spec
# 11 and the eSocial pending item (RN-04-063) with spec 13.
class EmploymentRevision < ApplicationRecord
  SALARY_UNITS = %w[hour day week fortnight month task variable_only].freeze
  REASONS = %w[admission promotion salary_change transfer schedule_change collective_agreement correction other].freeze
  # The reasons the HR picks for a new revision; the admission one is the first's.
  CHANGE_REASONS = (REASONS - %w[admission]).freeze

  audited sensitive: %i[salary_cents]

  acts_as_tenant :company

  belongs_to :employment
  belongs_to :position
  belongs_to :unit
  belongs_to :department, optional: true
  belongs_to :allocation_client, optional: true
  belongs_to :created_by, class_name: "User"

  attribute :salary_cents, :integer
  encrypts :salary_cents

  enum :salary_unit, SALARY_UNITS.index_by(&:itself), validate: true, prefix: :paid_by
  enum :reason, REASONS.index_by(&:itself), validate: true, prefix: true

  normalizes :justification, :variable_salary_description, with: ->(text) { text.to_s.strip.presence }

  before_validation :copy_cbo, if: -> { position && (new_record? || position_id_changed?) }
  before_update :only_future_changes
  before_destroy :only_future_changes
  before_destroy :keep_first_revision
  # The open processes follow a new allocation client once in force (RN-06-036, D-641);
  # a future one, on its date (Employments::ApplyScheduledRevisionsJob).
  after_create_commit -> { Processes::FollowClientChange.call(employment, by: created_by) }, unless: :future?

  validates :effective_on, presence: true
  validates :salary_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validates :salary_cents, presence: true, unless: -> { paid_by_variable_only? || employment&.pending? }
  validates :variable_salary_description, presence: true, if: :paid_by_variable_only?
  validates :weekly_hours, numericality: { greater_than: 0, less_than: 100 }, allow_nil: true
  validate :justified_when_out_of_range
  validate :within_employment
  validate :assignable_records
  validate :department_of_unit
  validate :allocation_client_allowed
  validate :same_company

  def audit_company_id
    company_id
  end

  # The revision that counts for each employment on the date: the one in force, or, before
  # the employment starts, the first (RN-04-061, D-603). Use it as a table:
  # EmploymentRevision.from(EmploymentRevision.counting_on(date), :employment_revisions).
  def self.counting_on(date = Date.current)
    order_sql = sanitize_sql_array([ <<~SQL.squish, date, date ])
      employment_revisions.employment_id,
      (employment_revisions.effective_on <= ?) DESC,
      CASE WHEN employment_revisions.effective_on <= ? THEN employment_revisions.effective_on END DESC NULLS LAST,
      employment_revisions.effective_on ASC,
      employment_revisions.id DESC
    SQL
    select("DISTINCT ON (employment_revisions.employment_id) employment_revisions.*").reorder(Arel.sql(order_sql))
  end

  def self.counting(date = Date.current)
    from(counting_on(date), :employment_revisions)
  end

  # Revisions that place an open employment somewhere, now or from a future date: a unit
  # or a department with any of them is not inactivated (RN-04-014, RN-04-025).
  def self.placing_open_employments
    where(employment_id: Employment.open.select(:id))
      .where("employment_revisions.id IN (?) OR employment_revisions.effective_on > ?", counting.select(:id), Date.current)
  end

  # Only a monthly salary is compared with the position's range, which is monthly
  # (RN-04-032, D-603).
  def out_of_range?
    paid_by_month? && !salary_cents.nil? && position.present? && !position.within_range?(salary_cents)
  end

  def future?
    effective_on.present? && effective_on > Date.current
  end

  # Until the employment starts, the first revision is completed by the HR, even on the
  # start's own day: the salary and the rest come up to the review (RN-07-011).
  def changeable?
    future? || employment.pending?
  end

  # The first revision of an employment still in admission (RN-07-011, D-648).
  def completed_by_admission?
    reason_admission? && employment.pending? && employment.admission&.open? == true
  end

  # A revision dated before today, after the first one, may require recalculating closed
  # payrolls and rectifying the eSocial (RN-04-062, P-04-21; specs 12 and 13).
  def retroactive?
    effective_on.present? && effective_on < Date.current && !reason_admission?
  end

  private

  def copy_cbo
    self.cbo_code = position.cbo_code
  end

  def only_future_changes
    return if effective_on_in_database.nil? || effective_on_in_database > Date.current || employment.pending?

    errors.add(:base, :in_force)
    throw :abort
  end

  def keep_first_revision
    return unless reason_admission?

    errors.add(:base, :first_revision)
    throw :abort
  end

  # The salary is not blocked: it asks for the justification (CA-04-005).
  def justified_when_out_of_range
    return if justification.present? || !out_of_range?

    errors.add(:justification, :out_of_range, range: position.salary_range_text)
  end

  def within_employment
    return if employment.nil? || effective_on.nil?

    errors.add(:effective_on, :before_start) if effective_on < employment.started_on
  end

  # A new choice must be active; a revision keeps a position, unit or department that was
  # inactivated later.
  def assignable_records
    errors.add(:position, :inactive) if position&.inactive? && (new_record? || position_id_changed?)
    errors.add(:unit, :inactive) if unit&.inactive? && (new_record? || unit_id_changed?)
    errors.add(:department, :inactive) if department&.inactive? && (new_record? || department_id_changed?)
  end

  # Only a company that uses allocation clients points to one, and a new choice must be
  # active (RN-04-090, RN-04-092).
  def allocation_client_allowed
    return if allocation_client.nil?

    errors.add(:allocation_client, :not_in_use) unless employment&.company&.uses_allocation_clients
    errors.add(:allocation_client, :inactive) if allocation_client.inactive? && (new_record? || allocation_client_id_changed?)
  end

  # RN-04-064.
  def department_of_unit
    errors.add(:department, :other_unit) if department && unit && department.unit_id != unit.id
  end

  def same_company
    return if employment.nil?

    errors.add(:employment, :other_company) if employment.company_id != company_id
  end
end
