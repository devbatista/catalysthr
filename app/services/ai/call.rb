module Ai
  # One call of a function for a company (spec 14): the call itself, its record without the
  # content (RN-14-131), the credits when it works (RN-14-110) and nothing when it fails
  # (RN-14-113), and the circuit breaker (RN-14-123). The block gets the client and returns the
  # Client::Result; the caller checks Availability before and owns the new tries.
  #
  #   result = Ai::Call.run(company:, feature: "document_extraction", subject: version,
  #     prompt_version: Prompt::VERSION, attempt: executions) { |client| client.structured(...) }
  module Call
    module_function

    def run(company:, feature:, prompt_version:, subject: nil, user: nil, attempt: 1, quantity: 1)
      feature = Features.find(feature)
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      record = { company: company, user: user, feature: feature.code, provider: "anthropic", prompt_version: prompt_version,
        subject: subject, attempt: attempt }
      begin
        result = yield Client.new(timeout: feature.timeout)
      rescue Ai::Error => error
        failed(record.merge(model: Client.model, error_code: error.code, latency_ms: elapsed(started)))
        raise
      end

      succeeded(record, result, feature, quantity, elapsed(started), company)
      result
    end

    def succeeded(record, result, feature, quantity, latency, company)
      AiRequest.transaction do
        request = AiRequest.create!(record.merge(status: "succeeded", model: result.model, latency_ms: latency,
          provider_request_id: result.message_id, input_tokens: result.input_tokens, output_tokens: result.output_tokens,
          cache_read_tokens: result.cache_read_tokens, cache_write_tokens: result.cache_write_tokens,
          cost_usd_micros: result.cost_usd_micros, credits: Credits.for(feature, quantity: quantity)))
        Credits.charge!(request, company: company)
      end
      log(record, "succeeded", latency)
      Breaker.observe
    end

    def failed(record)
      AiRequest.create!(record.merge(status: "failed", credits: 0))
      log(record, "failed", record[:latency_ms], record[:error_code])
      Breaker.observe
    end

    def elapsed(started) = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).round

    # Only the metadata goes to the logs (RN-14-131).
    def log(record, status, latency, error_code = nil)
      Rails.logger.info("ai.call feature=#{record[:feature]} company=#{record[:company]&.id} status=#{status} " \
        "attempt=#{record[:attempt]} latency_ms=#{latency}#{" error=#{error_code}" if error_code}")
    end
  end
end
