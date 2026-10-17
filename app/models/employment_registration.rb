# A new employment with its first revision, for someone who already has a record in the
# company (RN-04-051): a second contract, or the intern's conversion to CLT (RN-04-054,
# CA-04-006). The conversion ends the internship the day before the CLT admission, with
# the reason "conversion" (D-604). The "Novo colaborador" form builds on this one.
#
# As in the manual registration (D-600), the start is not in the future: who has not
# started yet comes through the admission (spec 07).
class EmploymentRegistration
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :kind, :string, default: "clt"
  attribute :category, :string, default: "standard"
  attribute :registration_number, :string
  attribute :started_on, :date
  attribute :position_id, :integer
  attribute :unit_id, :integer
  attribute :department_id, :integer
  attribute :salary, :string
  attribute :salary_unit, :string, default: "month"
  attribute :variable_salary_description, :string
  attribute :weekly_hours, :decimal
  attribute :justification, :string

  attr_reader :employment

  # Where each record's error shows on the form.
  FIELDS = {
    [ "Employment", :kind ] => :kind, [ "Employment", :category ] => :category,
    [ "Employment", :registration_number ] => :registration_number, [ "Employment", :started_on ] => :started_on,
    [ "EmploymentRevision", :position ] => :position_id, [ "EmploymentRevision", :unit ] => :unit_id,
    [ "EmploymentRevision", :department ] => :department_id, [ "EmploymentRevision", :salary_cents ] => :salary,
    [ "EmploymentRevision", :salary_unit ] => :salary_unit,
    [ "EmploymentRevision", :variable_salary_description ] => :variable_salary_description,
    [ "EmploymentRevision", :weekly_hours ] => :weekly_hours, [ "EmploymentRevision", :justification ] => :justification
  }.freeze

  validates :started_on, presence: true
  validate :started_already

  def self.model_name
    ActiveModel::Name.new(self, nil, "EmploymentForm")
  end

  # The conditions of the CLT employment start from the internship's: unit, department
  # and weekly hours (D-604).
  def self.conversion_of(internship, company:)
    revision = internship.current_revision || internship.effective_revision
    new(kind: "clt", registration_number: company.suggested_registration_number, unit_id: revision&.unit_id,
      department_id: revision&.department_id, weekly_hours: revision&.weekly_hours)
  end

  def save(profile:, by:, converting: nil)
    return false unless valid? && convertible?(converting)

    with_salary do |salary_cents|
      company = profile.company
      company.lock!
      converting&.update!(status: "terminated", ended_on: started_on - 1, termination_reason: "conversion")
      create_employment!(profile, by, salary_cents)
      AccessEvent.record!(kind: "admin", action: converting ? "intern_converted" : "employment_added", user: by,
        subject: @employment)
    end
  end

  private

  # Parses the salary and runs the block in a transaction; false with the errors on the
  # form when anything is refused.
  def with_salary
    salary_cents = MoneyCents.parse(salary)
    return add_error(:salary, :invalid_amount) if salary_cents == :invalid

    ActiveRecord::Base.transaction { yield salary_cents }
    errors.none?
  rescue ActiveRecord::RecordInvalid => error
    merge_errors(error.record)
    false
  rescue ActiveRecord::RecordNotUnique
    add_error(:registration_number, :taken)
  end

  def create_employment!(profile, by, salary_cents)
    @employment = profile.employments.create!(kind: kind, category: category, registration_number: registration_number,
      started_on: started_on, status: "active")
    @employment.revisions.create!(
      effective_on: started_on, position_id: position_id, unit_id: unit_id, department_id: department_id,
      salary_cents: salary_cents, salary_unit: salary_unit, variable_salary_description: variable_salary_description,
      weekly_hours: weekly_hours, reason: "admission", justification: justification, created_by: by
    )
    profile.company.advance_registration_number!(@employment.registration_number)
  end

  # Only an open internship becomes CLT, from a day after its start (CA-04-006).
  def convertible?(internship)
    return true if internship.nil?

    errors.add(:base, :not_internship) unless internship.intern? && internship.open?
    errors.add(:kind, :clt_only) unless kind == "clt"
    errors.add(:started_on, :before_internship) if started_on <= internship.started_on
    errors.none?
  end

  def merge_errors(record)
    record.errors.each do |error|
      attribute = self.class::FIELDS.fetch([ record.class.name, error.attribute ], nil)
      attribute ? errors.add(attribute, error.message) : errors.add(:base, error.full_message)
    end
  end

  def add_error(attribute, type)
    errors.add(attribute, type)
    false
  end

  def started_already
    errors.add(:started_on, :future) if started_on && started_on > Date.current
  end
end
