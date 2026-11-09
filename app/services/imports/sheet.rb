module Imports
  # A sheet of a kind, with its columns.
  Sheet = Data.define(:key, :title, :columns) do
    def column(key) = columns.find { |column| column.key == key }
  end
end
