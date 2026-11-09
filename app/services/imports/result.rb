module Imports
  # What the validation says of a line (RN-18-006): valid, invalid or unchanged; the action;
  # the errors by column and the fields that change, before and after.
  Result = Data.define(:sheet, :line, :values, :status, :action, :issues, :diff) do
    def self.for(line, issues: [], action: "none", diff: {})
      status = if issues.any? then "invalid"
      elsif action == "none" then "unchanged"
      else "valid"
      end
      new(line.sheet, line.number, line.values, status, action, issues, diff)
    end
  end
end
