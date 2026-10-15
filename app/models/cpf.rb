# CPF normalization, check digits and display (RN-02-001, RN-02-003).
#
# Modulo 11: the first check digit uses weights 10..2 over the 9 base digits, the
# second uses weights 11..2 over the base plus the first digit (Receita Federal).
module Cpf
  FORMAT = /\A\d{11}\z/
  # Only digits and CPF punctuation: what the sign-in field treats as a CPF (P-02-05).
  LOOKS_LIKE_CPF = /\A[\d.\-\s]+\z/

  module_function

  # "123.456.789-09" => "12345678909"
  def normalize(value)
    value.to_s.gsub(/\D/, "")
  end

  def looks_like_cpf?(value)
    value.to_s.strip.match?(LOOKS_LIKE_CPF)
  end

  def valid?(value)
    cpf = normalize(value)
    return false unless cpf.match?(FORMAT)
    return false if cpf.chars.uniq.size == 1

    base = cpf[0, 9]
    first = check_digit(base)
    second = check_digit(base + first.to_s)
    cpf.end_with?("#{first}#{second}")
  end

  # "12345678909" => "123.456.789-09"
  def format(value)
    cpf = normalize(value)
    return cpf unless cpf.size == 11

    "#{cpf[0, 3]}.#{cpf[3, 3]}.#{cpf[6, 3]}-#{cpf[9, 2]}"
  end

  def check_digit(digits)
    weight = digits.size + 1
    sum = digits.each_char.with_index.sum { |digit, index| digit.to_i * (weight - index) }
    remainder = sum % 11
    remainder < 2 ? 0 : 11 - remainder
  end
end
