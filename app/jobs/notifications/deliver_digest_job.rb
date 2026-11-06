module Notifications
  # Sends a digest through SES, with the attempts of RN-15-084. If it fails, every delivery
  # in it fails, and each mandatory notice looks for its next channel (RN-15-081). Runs once
  # per digest: one already sent is left alone.
  class DeliverDigestJob < ApplicationJob
    queue_as :notifications

    WAITS = DeliverEmailJob::WAITS
    TEMPORARY = DeliverEmailJob::TEMPORARY

    retry_on(*TEMPORARY, attempts: WAITS.size + 1, wait: ->(executions) { WAITS.fetch(executions - 1, WAITS.last) }) do |job, error|
      job.arguments.first.deliveries.each { |delivery| delivery.update!(status: "failed", failed_reason: error.class.name.demodulize) }
    end

    def perform(digest)
      return if digest.sent_at

      deliveries = digest.deliveries.where(status: %w[queued sending]).to_a
      return if deliveries.empty?

      deliveries.each { |delivery| delivery.update!(status: "sending", attempts: delivery.attempts + 1) }
      message = NotificationMailer.digest(digest).deliver_now
      digest.update!(sent_at: Time.current, provider_message_id: message.header[:ses_message_id]&.value)
      deliveries.each { |delivery| delivery.update!(status: "sent", sent_at: digest.sent_at) }
    rescue *TEMPORARY
      raise
    rescue Aws::SESV2::Errors::ServiceError => error
      deliveries.each { |delivery| delivery.update!(status: "failed", failed_reason: error.class.name.demodulize) }
    end
  end
end
