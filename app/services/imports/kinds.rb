module Imports
  # The kinds of import (spec 18, section 4.2), in the order the implementation recommends
  # (P-18-08). Each kind says its sheets and columns, who may use it, the formats it takes,
  # how a line is validated and how it is recorded. Blocks 18b to 18f add the others (D-661).
  module Kinds
    ALL = {
      "structure" => "Imports::Structure",
      "employees" => "Imports::Employees",
      "dependents" => "Imports::Dependents",
      "bank_accounts" => "Imports::BankAccounts",
      "department_managers" => "Imports::DepartmentManagers",
      "employment_history" => "Imports::EmploymentHistory",
      "admissions" => "Imports::Admissions"
    }.freeze

    module_function

    def codes
      ALL.keys
    end

    def fetch(code)
      ALL.fetch(code).constantize
    end

    # The kinds whose module is on: the admissions wait for their flag (D-648, D-668).
    def all
      ALL.values.map(&:constantize).select { |kind| !kind.respond_to?(:available?) || kind.available? }
    end
  end
end
