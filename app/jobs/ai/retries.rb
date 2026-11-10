module Ai
  # The new tries of the AI jobs (spec 14, RN-14-120, RN-14-121, D-383, P-14-29): a rate limit,
  # an overload, a server error or a time out are tried 3 more times, after 1, 5 and 15 minutes;
  # an invalid request or answer once more, after 1 minute. Then the job's `ai_failed!` sends
  # the item to the manual flow, marked "falha da IA", where the HR may process it again.
  #
  # A job that finds the queue paused by the circuit breaker waits for it with `wait_for_breaker`,
  # without spending a try (RN-14-123).
  module Retries
    extend ActiveSupport::Concern

    TRANSIENT_WAITS = [ 1.minute, 5.minutes, 15.minutes ].freeze

    included do
      queue_as :ai

      retry_on Ai::TransientError, attempts: TRANSIENT_WAITS.size + 1,
        wait: ->(executions) { TRANSIENT_WAITS.fetch(executions - 1, TRANSIENT_WAITS.last) } do |job, error|
        job.ai_failed!(error)
      end

      retry_on Ai::InvalidResponse, attempts: 2, wait: 1.minute do |job, error|
        job.ai_failed!(error)
      end
    end

    def wait_for_breaker
      retry_job(wait_until: (Breaker.open_until || Time.current) + 5.seconds)
    end

    # The number of this try, for the AiRequest.
    def ai_attempt = executions

    def ai_failed!(_error)
      raise NotImplementedError
    end
  end
end
