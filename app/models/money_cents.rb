# Amounts are kept in integer cents (AGENTS.md, section 4) and shown in reais.
module MoneyCents
  module_function

  # "R$ 2.500,50", "2500,5" or "2500.50" => 250050; blank => nil; anything else => :invalid.
  def parse(value)
    text = value.to_s.strip.delete_prefix("R$").strip
    return if text.empty?

    text = text.delete(".").tr(",", ".") if text.include?(",")
    return :invalid unless text.match?(/\A\d+(\.\d{1,2})?\z/)

    (BigDecimal(text) * 100).to_i
  end

  # 250050 => "2.500,50"
  def format(cents)
    return "" if cents.nil?

    reais, centavos = cents.divmod(100)
    "#{reais.to_s.reverse.scan(/\d{1,3}/).join(".").reverse},#{centavos.to_s.rjust(2, "0")}"
  end

  # 250050 => "2500.50", as payment APIs take it.
  def decimal(cents)
    reais, centavos = cents.divmod(100)
    "#{reais}.#{centavos.to_s.rjust(2, "0")}"
  end
end
