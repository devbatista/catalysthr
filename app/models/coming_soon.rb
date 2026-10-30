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
  # Features that are modules released by membership (spec 03, section 2.3): an HR
  # analyst or a consultant sees them only when released to them (CA-03-001).
  RELEASED_MODULES = { "admissions" => "admissao", "documents" => "documentos", "requests" => "solicitacoes",
    "payroll" => "folha", "time-tracking" => "ponto", "performance" => "avaliacao" }.freeze

  module_function

  # A module released by membership only for who operates it (CA-03-001).
  def released?(feature, ability)
    code = RELEASED_MODULES[feature]
    code.nil? || ability.can?(:use_module, code.to_sym)
  end

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
