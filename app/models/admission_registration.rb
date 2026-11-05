# The initial registration of an admission (RN-07-010 to RN-07-014, D-254). Unlike "Novo
# colaborador", which is for who already works in the company, the start is today or later
# (D-648), the employment is born pending, the invitation doesn't go out (D-252) and the
# process starts from the model of the position or the employment kind (RN-07-013). The
# salary and the rest come later, up to the HR's review (RN-07-011).
#
# A CPF with an account or a record keeps them (RN-07-012, P-02-08); another open employment
# in the company only shows an alert (RN-07-014, D-205).
class AdmissionRegistration < EmployeeRegistration
  attr_reader :admission

  validates :name, presence: true
  validates :position_id, :unit_id, :department_id, presence: true
  validate :contact_given

  def self.model_name
    ActiveModel::Name.new(self, nil, "Admission")
  end

  # starter: who starts the process, as in Processes::Start.
  def save(company:, by:, starter:)
    return false unless valid?

    template = Admissions.template_for(position_id: position_id, kind: kind)
    return add_error(:base, :no_template) if template.nil?

    with_salary do |salary_cents|
      company.lock!
      self.registration_number = company.suggested_registration_number
      membership = employee_membership(company)
      @existing_person = @existing_person || WorkerProfile.exists?(membership: membership)
      @profile = WorkerProfile.find_or_create_by!(membership: membership) { |profile| profile.social_name = social_name }
      create_employment!(@profile, by, salary_cents)
      instance = Admissions.start_process(template: template, employment: @employment, by: by, starter: starter)
      @admission = Admission.create!(employment: @employment, process_instance: instance,
        esocial_status: @employment.contractor? ? "not_applicable" : "not_sent")
      AccessEvent.record!(kind: "admin", action: "admission_created", user: by, subject: @admission)
    end
  end

  private

  def employment_status
    "pending"
  end

  # The admission reuses the record (RN-07-012).
  def duplicate_record?(_membership)
    false
  end

  # Who already started comes through "Novo colaborador" (D-648).
  def started_already
    return if started_on.nil?

    unit = Unit.find_by(id: unit_id)
    errors.add(:started_on, :past) if started_on < Time.find_zone(unit&.time_zone || "America/Sao_Paulo").today
  end

  def contact_given
    errors.add(:base, :contact_blank) if email.blank? && mobile_phone.blank?
  end
end
