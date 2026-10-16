# The single point where a sensitive value reaches a page (spec 05, RN-05-001, P-05-06).
# During an impersonate the value is masked (RN-02-086, D-187). The password
# confirmation (RN-02-052) and the read event come with spec 04 (D-592).
module SensitiveData
  MONEY_MASK = "R$ ••••".freeze

  module_function

  def reveal(value, as:)
    return value if value.blank? || Current.impersonation.nil?

    mask(value, as: as)
  end

  # CPF partial (***.456.789-**), amounts hidden, bank data with only its last digits.
  def mask(value, as:)
    case as
    when :cpf
      digits = Cpf.normalize(value)
      "***.#{digits[3, 3]}.#{digits[6, 3]}-**"
    when :money then MONEY_MASK
    when :bank_account then "••••#{value.to_s.gsub(/\D/, "").last(2)}"
    else raise ArgumentError, "unknown sensitive type: #{as.inspect}"
    end
  end
end
