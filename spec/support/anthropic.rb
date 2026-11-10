# Claude for the specs (spec 14, RN-14-141, P-14-35): no spec calls the API; the answers are
# recorded here and served by WebMock.
module AnthropicHelpers
  MESSAGES_URL = "https://api.anthropic.com/v1/messages".freeze

  def configure_anthropic(key: "sk-ant-test")
    Rails.configuration.x.anthropic_api_key = key
  end

  # A structured answer with the JSON given, or a status with an error.
  def stub_claude(data = nil, status: 200, stop_reason: "end_turn", text: nil, usage: {})
    body = if status == 200
      claude_message(text || data.to_json, stop_reason: stop_reason, usage: usage)
    else
      { type: "error", error: { type: status == 429 ? "rate_limit_error" : "api_error", message: "stubbed" } }
    end
    stub_request(:post, MESSAGES_URL).to_return(status: status, body: body.to_json, headers: { "Content-Type" => "application/json" })
  end

  def claude_message(text, stop_reason: "end_turn", usage: {})
    {
      id: "msg_#{SecureRandom.hex(6)}", type: "message", role: "assistant", model: "claude-sonnet-5-5",
      content: [ { type: "text", text: text } ], stop_reason: stop_reason, stop_sequence: nil, stop_details: nil,
      container: nil, diagnostics: nil,
      usage: { input_tokens: 1_000, output_tokens: 200, cache_read_input_tokens: 0, cache_creation_input_tokens: 0 }.merge(usage)
    }
  end
end

RSpec.configure do |config|
  config.include AnthropicHelpers
  config.after { Rails.configuration.x.anthropic_api_key = nil }
end
