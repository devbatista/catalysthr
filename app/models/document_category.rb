# The fixed categories of the folder (spec 08, D-270, P-08-01), in the folder's order, and
# which ones are sensitive (spec 05): opening their files asks for the password and
# becomes an access event (RN-08-081, P-08-20). Health is only for the HR (P-03-17,
# P-03-18), and the payroll's only for who reads pay (P-03-16, D-642).
module DocumentCategory
  ALL = %w[personal admission health dependents statements contracts payroll time_tracking other].freeze
  SENSITIVE = %w[personal admission health dependents payroll].freeze

  module_function

  def sensitive?(category)
    SENSITIVE.include?(category)
  end

  # The categories a person may read in a folder they reach.
  def readable(health:, pay:)
    ALL.reject { |category| (category == "health" && !health) || (category == "payroll" && !pay) }
  end
end
