# validates :cnpj, cnpj: true
class CnpjValidator < ActiveModel::EachValidator
  def validate_each(record, attribute, value)
    return if value.blank?

    record.errors.add(attribute, :invalid_cnpj) unless Cnpj.valid?(value)
  end
end
