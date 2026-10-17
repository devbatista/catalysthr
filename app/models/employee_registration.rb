# The "Novo colaborador" form (RN-04-040, D-600): before the admission (spec 07) and the
# import (spec 18), the HR registers by hand who already works in the company. It creates
# the person, the employee membership without sending an invitation (the employee's
# invitation comes with spec 16), the record, the employment and its first revision.
#
# A CPF that already has an account keeps the same person (D-209, D-602): the new record
# is linked to it, nothing of another company is shown or changed, and the sign-in
# e-mail and mobile phone stay as they are.
class EmployeeRegistration < EmploymentRegistration
  attribute :name, :string
  attribute :cpf, :string
  attribute :birth_date, :date
  attribute :email, :string
  attribute :mobile_phone, :string
  attribute :social_name, :string

  attr_reader :profile, :existing_person

  FIELDS = EmploymentRegistration::FIELDS.merge(
    [ "User", :name ] => :name, [ "User", :cpf ] => :cpf, [ "User", :birth_date ] => :birth_date,
    [ "User", :email ] => :email, [ "User", :mobile_phone ] => :mobile_phone,
    [ "WorkerProfile", :social_name ] => :social_name
  ).freeze

  validates :cpf, presence: true, cpf: true

  def self.model_name
    ActiveModel::Name.new(self, nil, "Employee")
  end

  def save(company:, by:)
    return false unless valid?

    with_salary do |salary_cents|
      company.lock!
      membership = employee_membership(company)
      @profile = WorkerProfile.create!(membership: membership, social_name: social_name)
      create_employment!(@profile, by, salary_cents)
      AccessEvent.record!(kind: "admin", action: "employee_registered", user: by, subject: membership)
    end
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
end
