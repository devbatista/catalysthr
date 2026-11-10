module Ai
  # The call to Claude (spec 14, P-14-39): the official SDK, through the Messages API only, with
  # the answer in JSON by a schema and the files inside the call, in base64, never through the
  # Files API nor the Batch API (RN-14-003, D-385). The SDK tries nothing again by itself: the
  # jobs own the new tries (RN-14-120). Nothing of the content is logged (RN-14-131).
  class Client
    BASE_URL = "https://api.anthropic.com".freeze
    # US$ per million tokens of each model (input, output, cache read, cache write), the
    # Anthropic's list prices, for the cost of each call (RN-14-110). A model without a price
    # records cost zero, and the team sees it in the admin.
    PRICES = {
      "claude-sonnet-5-5" => { input: 2.0, output: 10.0, cache_read: 0.2, cache_write: 2.5 }
    }.freeze

    Result = Data.define(:data, :model, :message_id, :input_tokens, :output_tokens, :cache_read_tokens,
      :cache_write_tokens) do
      def cost_usd_micros
        price = PRICES[model]
        return 0 unless price

        (input_tokens * price[:input] + output_tokens * price[:output] + cache_read_tokens * price[:cache_read] +
          cache_write_tokens * price[:cache_write]).round
      end
    end

    def self.configured? = Rails.configuration.x.anthropic_api_key.present?
    def self.model = Rails.configuration.x.ai_model

    def initialize(timeout:)
      @sdk = Anthropic::Client.new(api_key: Rails.configuration.x.anthropic_api_key, base_url: BASE_URL, max_retries: 0,
        timeout: timeout)
    end

    # One call with the instructions, the content (text, PDF or image blocks) and the answer's
    # schema. The instructions say the content is data, never instruction (RN-14-004); a long
    # and fixed part of them may go to the prompt cache (RN-14-052).
    def structured(system:, content:, schema:, max_tokens:, cached_system: nil, effort: nil)
      message = @sdk.messages.create(**params(system, content, schema, max_tokens, cached_system, effort))
      Result.new(data: read(message, schema), model: message.model.to_s, message_id: message.id,
        **usage(message.usage))
    rescue Anthropic::Errors::APIConnectionError => error
      raise TransientError, error.is_a?(Anthropic::Errors::APITimeoutError) ? "timeout" : "connection"
    rescue Anthropic::Errors::APIStatusError => error
      raise classify(error)
    end

    private

    def params(system, content, schema, max_tokens, cached_system, effort)
      blocks = []
      blocks << { type: "text", text: cached_system, cache_control: { type: "ephemeral" } } if cached_system
      blocks << { type: "text", text: system }
      {
        model: self.class.model, max_tokens: max_tokens, system_: blocks,
        messages: [ { role: "user", content: content } ],
        output_config: { format_: { type: :json_schema, schema: schema }, effort: effort }.compact
      }
    end

    def read(message, schema)
      case message.stop_reason
      when :refusal then raise InvalidResponse, "refusal"
      when :max_tokens then raise InvalidResponse, "max_tokens"
      end

      text = message.content.select { |block| block.type == :text }.map(&:text).join
      Schema.validate!(JSON.parse(text), schema)
    rescue JSON::ParserError
      raise InvalidResponse, "invalid_json"
    end

    def usage(usage)
      { input_tokens: usage.input_tokens.to_i, output_tokens: usage.output_tokens.to_i,
        cache_read_tokens: usage.cache_read_input_tokens.to_i, cache_write_tokens: usage.cache_creation_input_tokens.to_i }
    end

    # 429, 529, 5xx, 408 and 409 are tried again; the other 4xx are invalid requests.
    def classify(error)
      code = "http_#{error.status}"
      transient = error.status.to_i >= 500 || error.status.to_i.in?([ 408, 409, 429 ])
      transient ? TransientError.new(code) : InvalidResponse.new(code)
    end
  end
end
