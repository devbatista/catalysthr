module Ai
  # Checks an answer against the JSON schema sent with it, before anything uses it (RN-14-004,
  # P-14-03). The structured output already follows the schema; this keeps a changed or
  # cut answer from reaching the screens. It covers the part of JSON Schema our schemas use:
  # type (one or a list), properties, required, additionalProperties false, items and enum.
  module Schema
    TYPES = {
      "object" => ->(value) { value.is_a?(Hash) },
      "array" => ->(value) { value.is_a?(Array) },
      "string" => ->(value) { value.is_a?(String) },
      "integer" => ->(value) { value.is_a?(Integer) },
      "number" => ->(value) { value.is_a?(Numeric) },
      "boolean" => ->(value) { value == true || value == false },
      "null" => lambda(&:nil?)
    }.freeze

    module_function

    def validate!(data, schema)
      error = first_error(data, schema.deep_stringify_keys, "$")
      raise InvalidResponse.new("schema_mismatch", "schema_mismatch at #{error}") if error
      data
    end

    def first_error(value, schema, path)
      types = Array(schema["type"])
      return path if types.any? && types.none? { |type| TYPES.fetch(type).call(value) }
      return path if schema.key?("enum") && !schema["enum"].include?(value)

      case value
      when Hash then object_error(value, schema, path)
      when Array then value.each_with_index.lazy.filter_map { |item, index| first_error(item, schema.fetch("items", {}), "#{path}[#{index}]") }.first
      end
    end

    def object_error(value, schema, path)
      properties = schema.fetch("properties", {})
      missing = Array(schema["required"]).find { |key| !value.key?(key) }
      return "#{path}.#{missing}" if missing
      extra = value.keys.find { |key| !properties.key?(key) } if schema["additionalProperties"] == false
      return "#{path}.#{extra}" if extra

      value.lazy.filter_map { |key, item| properties[key] && first_error(item, properties[key], "#{path}.#{key}") }.first
    end
  end
end
