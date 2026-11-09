module Imports
  # A column of a sheet: the key, the header the file brings (recognized by the name, not by
  # the position, RN-18-003), whether it is required, a hint and the list of options for the
  # template. digits: a code of fixed length (CEP, CBO) that a spreadsheet kept as a number
  # comes back with its leading zeros. sensitive: how a sensitive value is masked on the
  # preview and the result (SensitiveData.mask, D-086, D-663).
  Column = Data.define(:key, :header, :required, :hint, :options, :digits, :sensitive) do
    def initialize(key:, header:, required: false, hint: nil, options: nil, digits: nil, sensitive: nil)
      super
    end

    # The cell's text, with the leading zeros a number lost.
    def read(text)
      return text unless digits && text&.match?(/\A\d+\z/) && text.size < digits

      text.rjust(digits, "0")
    end
  end
end
