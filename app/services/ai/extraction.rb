module Ai
  # The fields the AI returned, cleaned before anything uses them (RN-14-004, RN-14-022): only the
  # profile's keys, once each; the digits of the CPF, the PIS and the CEP; the state in capitals;
  # a date only when it is a real one. And the checks that ask another service, done once when
  # the reading ends: the CEP in ViaCEP (RN-14-022). The others are made on the review.
  module Extraction
    DIGITS = %i[cpf pis postal_code].freeze

    module_function

    def normalize(fields, profile)
      by_key = ExtractionProfiles.fields(profile).index_by(&:key)
      Array(fields).each_with_object({}) do |field, kept|
        definition = by_key[field["key"]]
        next if definition.nil? || kept.key?(definition.key)

        kept[definition.key] = { "key" => definition.key, "value" => clean(field["value"], definition.kind),
          "confidence" => field["confidence"], "page" => field["page"] }
      end.values
    end

    def clean(value, kind)
      text = value.to_s.strip.presence
      return if text.nil?

      case kind
      when *DIGITS then text.gsub(/\D/, "").presence
      when :state then text.upcase.first(2)
      when :cnh_category then text.upcase.delete(" ")
      when :date then (Date.iso8601(text).iso8601 rescue nil)
      when :aso_result then { "apto" => "fit", "inapto" => "unfit" }.fetch(text.downcase, text.downcase.presence_in(%w[fit unfit]))
      else text.first(500)
      end
    end

    # The CEP read is looked up once, so the review does not wait for ViaCEP.
    def lookups(fields)
      postal_code = fields.find { |field| field["key"] == "postal_code" }&.dig("value")
      return {} if postal_code.blank?

      { "postal_code" => Addresses::PostalCodeLookup.call(postal_code) ? "found" : "not_found" }
    end
  end
end
