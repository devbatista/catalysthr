module Notifications
  # Sends a notice by e-mail through SES, on behalf of the brand (RN-15-002, P-15-31).
  # A temporary failure of the provider gets 3 new attempts, 1, 5 and 15 minutes apart,
  # before counting as a failure (RN-15-084, P-15-27). A refusal by SES fails at once.
  # Runs once per delivery: a delivery already sent or failed is left alone.
  class DeliverEmailJob < ApplicationJob
    queue_as :notifications

    WAITS = [ 1.minute, 5.minutes, 15.minutes ].freeze
    TEMPORARY = [ Seahorse::Client::NetworkingError, Aws::SESV2::Errors::TooManyRequestsException,
      Aws::SESV2::Errors::InternalServiceErrorException ].freeze

    retry_on(*TEMPORARY, attempts: WAITS.size + 1, wait: ->(executions) { WAITS.fetch(executions - 1, WAITS.last) }) do |job, error|
      job.arguments.first.update!(status: "failed", failed_reason: error.class.name.demodulize)
    end

    def perform(delivery)
      return unless delivery.queued? || delivery.sending?

      notification = delivery.notification
      # The e-mail may have bounced since the notice was created (RN-15-083, D-609).
      unless notification.recipient_user.email_deliverable?(mandatory: notification.mandatory)
        return delivery.update!(status: "failed", failed_reason: "email_unavailable")
      end

      delivery.update!(status: "sending", attempts: delivery.attempts + 1)
      message = NotificationMailer.notice(notification).deliver_now
      delivery.update!(status: "sent", sent_at: Time.current, provider_message_id: message.header[:ses_message_id]&.value)
    rescue *TEMPORARY
      raise
    rescue Aws::SESV2::Errors::ServiceError => error
      delivery.update!(status: "failed", failed_reason: error.class.name.demodulize)
    end
  end
end
