# People registered through the "Novo colaborador" form (spec 04, block 4c-1), so the
# specs use the same path as the HR.
module EmployeeHelpers
  def create_position(company, name: "Analista de RH", cbo_code: "252405", **attributes)
    CboOccupation.find_or_create_by!(code: cbo_code) { |occupation| occupation.title = name }
    ActsAsTenant.with_tenant(company) { Position.create!(name: name, cbo_code: cbo_code, **attributes) }
  end

  def register_employee(company, by:, position:, name: "Ana Lima", cpf: generate(:cpf), unit: company.headquarters,
    department: nil, salary: "2.000,00", started_on: Date.new(2026, 3, 1), **attributes)
    ActsAsTenant.with_tenant(company) do
      registration = EmployeeRegistration.new({
        name: name, cpf: cpf, email: "#{cpf}@example.com", registration_number: company.reload.suggested_registration_number,
        started_on: started_on, position_id: position.id, unit_id: unit.id, department_id: department&.id, salary: salary
      }.merge(attributes))
      raise registration.errors.full_messages.to_sentence unless registration.save(company: company, by: by)

      registration.profile
    end
  end
end

RSpec.configure do |config|
  config.include EmployeeHelpers
end
