module Imports
  # The normalization before the validation (RN-18-004, P-18-03): documents and phones with or
  # without mask, dates in dd/mm/aaaa or aaaa-mm-dd, values with a decimal comma or point,
  # extra spaces removed and list texts compared without accents or case.
  module Normalize
    module_function

    # A cell as text: what a spreadsheet keeps as a number or a date comes back as typed.
    def text(value)
      case value
      when nil then nil
      when Date, Time, DateTime then value.to_date.iso8601
      when Float then (value % 1).zero? ? value.to_i.to_s : value.to_s
      else value.to_s.gsub(/\s+/, " ").strip.presence
      end
    end

    def digits(value)
      value.to_s.gsub(/\D/, "").presence
    end

    # A date, or :invalid.
    def date(value)
      return if value.blank?

      case value.to_s.strip
      when %r{\A(\d{1,2})/(\d{1,2})/(\d{4})\z} then Date.new(::Regexp.last_match(3).to_i, ::Regexp.last_match(2).to_i, ::Regexp.last_match(1).to_i)
      when /\A(\d{4})-(\d{2})-(\d{2})\z/ then Date.new(::Regexp.last_match(1).to_i, ::Regexp.last_match(2).to_i, ::Regexp.last_match(3).to_i)
      else :invalid
      end
    rescue Date::Error
      :invalid
    end

    # An amount in cents: "1.234,56", "1234,56", "1234.56" or "1234", or :invalid.
    def cents(value)
      return if value.blank?

      text = value.to_s.strip.delete(" ").delete_prefix("R$")
      text = text.delete(".").tr(",", ".") if text.include?(",")
      return :invalid unless text.match?(/\A\d+(\.\d{1,2})?\z/)

      (BigDecimal(text) * 100).to_i
    end

    # The text to compare a list's option: without accents, case or extra spaces.
    def key(value)
      I18n.transliterate(value.to_s).downcase.gsub(/\s+/, " ").strip
    end

    # The option of a list typed as its label or its code, or :invalid.
    def option(value, options)
      return if value.blank?

      wanted = key(value)
      found = options.find { |label, code| key(label) == wanted || key(code) == wanted }
      found ? found.last : :invalid
    end
  end
end
