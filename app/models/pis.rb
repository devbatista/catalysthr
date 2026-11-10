# The PIS/NIS check digit (spec 14, RN-14-022): modulo 11 over the first 10 digits with the
# weights 3, 2, 9, 8, 7, 6, 5, 4, 3 and 2; a result of 10 or 11 gives 0 (Caixa).
module Pis
  WEIGHTS = [ 3, 2, 9, 8, 7, 6, 5, 4, 3, 2 ].freeze

  module_function

  def valid?(value)
    digits = value.to_s.gsub(/\D/, "")
    return false unless digits.match?(/\A\d{11}\z/) && digits.chars.uniq.size > 1

    sum = digits[0, 10].chars.each_with_index.sum { |digit, index| digit.to_i * WEIGHTS[index] }
    check = 11 - (sum % 11)
    (check >= 10 ? 0 : check) == digits[10].to_i
  end
end
