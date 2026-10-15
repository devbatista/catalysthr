# CNPJ normalization and check digits, numeric and alphanumeric.
#
# From July 2026 the first 12 positions may hold uppercase letters; the two check
# digits stay numeric. Each character is worth its ASCII code minus 48, so digits
# keep their values and existing CNPJs are unchanged. Modulo 11 with weights 2..9
# from right to left (Receita Federal, "Manual de Cálculo do DV do CNPJ").
module Cnpj
  BASE_FORMAT = /\A[0-9A-Z]{12}[0-9]{2}\z/

  module_function

  # Keeps letters and digits, uppercased: "12.abc.345/01de-35" => "12ABC34501DE35"
  def normalize(value)
    value.to_s.upcase.gsub(/[^0-9A-Z]/, "")
  end

  def valid?(value)
    cnpj = normalize(value)
    return false unless cnpj.match?(BASE_FORMAT)
    return false if cnpj.chars.uniq.size == 1

    base = cnpj[0, 12]
    first = check_digit(base)
    second = check_digit(base + first.to_s)
    cnpj.end_with?("#{first}#{second}")
  end

  # "12ABC34501DE35" => "12.ABC.345/01DE-35"
  def format(value)
    cnpj = normalize(value)
    return cnpj unless cnpj.size == 14

    "#{cnpj[0, 2]}.#{cnpj[2, 3]}.#{cnpj[5, 3]}/#{cnpj[8, 4]}-#{cnpj[12, 2]}"
  end

  def check_digit(chars)
    sum = chars.reverse.each_char.with_index.sum do |char, index|
      (char.ord - 48) * (2 + index % 8)
    end
    remainder = sum % 11
    remainder < 2 ? 0 : 11 - remainder
  end
end
