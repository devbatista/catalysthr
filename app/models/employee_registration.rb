# The "Novo colaborador" form (RN-04-040, D-600): before the admission (spec 07) and the
# import (spec 18), the HR registers by hand who already works in the company. It creates
# the person, the employee membership without sending an invitation (the employee's
# invitation comes with spec 16), the record, the employment and its first revision.
#
# A CPF that already has an account keeps the same person (D-209, D-602): the new record
# is linked to it, nothing of another company is shown or changed, and the sign-in
# e-mail and mobile phone stay as they are.
class EmployeeRegistration
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :name, :string
  attribute :cpf, :string
  attribute :birth_date, :date
  attribute :email, :string
  attribute :mobile_phone, :string
  attribute :social_name, :string
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

  attr_reader :profile, :existing_person

  # Where each record's error shows on the form.
  FIELDS = {
    [ "User", :name ] => :name, [ "User", :cpf ] => :cpf, [ "User", :birth_date ] => :birth_date,
    [ "User", :email ] => :email, [ "User", :mobile_phone ] => :mobile_phone,
    [ "WorkerProfile", :social_name ] => :social_name,
    [ "Employment", :kind ] => :kind, [ "Employment", :category ] => :category,
    [ "Employment", :registration_number ] => :registration_number, [ "Employment", :started_on ] => :started_on,
    [ "EmploymentRevision", :position ] => :position_id, [ "EmploymentRevision", :unit ] => :unit_id,
    [ "EmploymentRevision", :department ] => :department_id, [ "EmploymentRevision", :salary_cents ] => :salary,
    [ "EmploymentRevision", :salary_unit ] => :salary_unit,
    [ "EmploymentRevision", :variable_salary_description ] => :variable_salary_description,
    [ "EmploymentRevision", :weekly_hours ] => :weekly_hours, [ "EmploymentRevision", :justification ] => :justification
  }.freeze

  validates :cpf, presence: true, cpf: true
  validates :started_on, presence: true
  validate :started_already

  def self.model_name
    ActiveModel::Name.new(self, nil, "Employee")
  end

  def save(company:, by:)
    return false unless valid?

    salary_cents = MoneyCents.parse(salary)
    return add_error(:salary, :invalid_amount) if salary_cents == :invalid

    ActiveRecord::Base.transaction do
      company.lock!
      membership = employee_membership(company)
      @profile = WorkerProfile.create!(membership: membership, social_name: social_name)
      employment = @profile.employments.create!(kind: kind, category: category, registration_number: registration_number,
        started_on: started_on, status: "active")
      employment.revisions.create!(
        effective_on: started_on, position_id: position_id, unit_id: unit_id, department_id: department_id,
        salary_cents: salary_cents, salary_unit: salary_unit, variable_salary_description: variable_salary_description,
        weekly_hours: weekly_hours, reason: "admission", justification: justification, created_by: by
      )
      company.advance_registration_number!(employment.registration_number)
      AccessEvent.record!(kind: "admin", action: "employee_registered", user: by, subject: membership)
    end
    errors.none?
  rescue ActiveRecord::RecordInvalid => error
    merge_errors(error.record)
    false
  rescue ActiveRecord::RecordNotUnique
    add_error(:registration_number, :taken)
  end

  private

  def employee_membership(company)
    user = User.find_by(cpf: Cpf.normalize(cpf))
    @existing_person = user.present?
    user ||= User.create!(name: name, cpf: cpf, birth_date: birth_date, email: email.presence,
      mobile_phone: mobile_phone.presence)

    membership = Membership.find_or_initialize_by(user: user, organization: company)
    if membership.persisted? && WorkerProfile.exists?(membership: membership)
      errors.add(:cpf, :already_registered)
      raise ActiveRecord::Rollback
    end

    if membership.new_record? || membership.revoked?
      membership.assign_attributes(roles: %w[employee], enabled_modules: [], status: "invited",
        invitation_token_digest: nil, invitation_channels: [])
    else
      membership.roles |= %w[employee]
    end
    membership.save!
    membership
  end

  def merge_errors(record)
    record.errors.each do |error|
      attribute = FIELDS.fetch([ record.class.name, error.attribute ], nil)
      attribute ? errors.add(attribute, error.message) : errors.add(:base, error.full_message)
    end
  end

  def add_error(attribute, type)
    errors.add(attribute, type)
    false
  end

  # Whoever has not started yet comes through the admission (spec 07).
  def started_already
    errors.add(:started_on, :future) if started_on && started_on > Date.current
  end
end
