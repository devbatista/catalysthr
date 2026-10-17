# Modules of the prototype not built yet. The menu lists them with "Em breve" and they
# open a coming-soon page (D-597). A module leaves this list when it is built.
module ComingSoon
  # The company's menu, by group, in the prototype's order.
  COMPANY_GROUPS = {
    operation: %w[admissions documents requests assistant],
    personnel: %w[payroll time-tracking performance],
    channels: %w[whatsapp accounting-integrations]
  }.freeze
  COMPANY_FEATURES = COMPANY_GROUPS.values.flatten.freeze
  PARTNER_FEATURES = %w[process-templates].freeze

  module_function

  def translation_key(feature)
    "navigation.features.#{feature.underscore}"
  end
end
