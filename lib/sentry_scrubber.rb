# Masks personal data before anything reaches Sentry (RN-20-071, P-20-25).
# Error context should carry only IDs; this is the safety net for messages
# that still contain a CPF, an e-mail or a phone number.
module SentryScrubber
  CPF = /\b\d{3}\.?\d{3}\.?\d{3}-?\d{2}\b/
  EMAIL = /\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b/i
  PHONE = /(?:\+?55\s?)?\(?\b\d{2}\)?\s?9?\d{4}-?\d{4}\b/

  module_function

  def mask(text)
    return text unless text.is_a?(String)

    text.gsub(CPF, "[cpf]").gsub(EMAIL, "[email]").gsub(PHONE, "[telefone]")
  end

  def scrub(event)
    event.message = mask(event.message) if event.message
    if event.respond_to?(:exception)
      event.exception&.values&.each { |value| value.value = mask(value.value) }
    end
    event.extra = deep_mask(event.extra) if event.extra
    event.tags = deep_mask(event.tags) if event.tags
    event
  end

  def deep_mask(value)
    case value
    when String then mask(value)
    when Hash then value.transform_values { |v| deep_mask(v) }
    when Array then value.map { |v| deep_mask(v) }
    else value
    end
  end
end
