# validates :cpf, cpf: true
class CpfValidator < ActiveModel::EachValidator
  def validate_each(record, attribute, value)
    return if value.blank?

    record.errors.add(attribute, :invalid_cpf) unless Cpf.valid?(value)
  end
end
