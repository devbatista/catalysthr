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
  # Features that are contracted modules (D-616): they show only when the contract has
  # them, and time tracking waits for the contract during the trial (CA-19-003).
  CONTRACT_MODULES = { "payroll" => "folha", "time-tracking" => "ponto" }.freeze
  PARTNER_FEATURES = %w[process-templates].freeze

  module_function

  def translation_key(feature)
    "navigation.features.#{feature.underscore}"
  end

  # :soon, :after_contract, or nil when the company does not have the feature.
  def state(feature, company)
    code = CONTRACT_MODULES[feature]
    return :soon if code.nil?

    case company.contract_modules.state(code)
    when :usable then :soon
    when :after_contract then :after_contract
    end
  end
end
