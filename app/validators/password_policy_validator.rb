# Password rules (RN-02-030, D-180, P-02-13): at least 8 characters, with an
# uppercase letter, a number and a symbol, and without the user's CPF or birth date.
#
#   validates :password, password_policy: true
class PasswordPolicyValidator < ActiveModel::EachValidator
  MINIMUM_LENGTH = 8
  # Bcrypt ignores what comes after 72 bytes.
  MAXIMUM_BYTES = 72
  # Separators people type inside a CPF or a date: "123.456.789-09", "15/03/1990".
  SEPARATORS = /[.\-\/\s]/

  def validate_each(record, attribute, value)
    return if value.nil?

    record.errors.add(attribute, :password_too_short, count: MINIMUM_LENGTH) if value.length < MINIMUM_LENGTH
    record.errors.add(attribute, :password_too_long) if value.bytesize > MAXIMUM_BYTES
    record.errors.add(attribute, :password_without_uppercase) unless value.match?(/[[:upper:]]/)
    record.errors.add(attribute, :password_without_number) unless value.match?(/\d/)
    record.errors.add(attribute, :password_without_symbol) unless value.match?(/[^[:alnum:]]/)
    record.errors.add(attribute, :password_with_personal_data) if personal_data?(record, value)
  end

  private

  def personal_data?(record, value)
    compact = value.gsub(SEPARATORS, "")
    forbidden = [ Cpf.normalize(record.cpf).presence, *birth_date_forms(record.birth_date) ].compact

    forbidden.any? { |data| compact.include?(data) }
  end

  def birth_date_forms(date)
    return [] if date.nil?

    [ date.strftime("%d%m%Y"), date.strftime("%Y%m%d"), date.strftime("%d%m%y") ]
  end
end
