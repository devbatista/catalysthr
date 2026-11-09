module Imports
  # A line of the file: the sheet, its number as the spreadsheet shows it, and the values by
  # column key, already as text.
  Line = Data.define(:sheet, :number, :values)
end
