module Notifications
  # One Web Push message to one subscription, signed with the VAPID keys of the environment
  # (RN-15-003, P-15-33). In development nothing leaves: it goes to the log, without the
  # text (P-15-34).
  module PushSender
    OPEN_TIMEOUT = 5
    READ_TIMEOUT = 10
    # A day is enough for a device off: an older notice is in the bell.
    TTL = 24.hours.to_i
    SUBJECT = "https://catalysthr.com.br"
    TEMPORARY = [ WebPush::TooManyRequests, WebPush::PushServiceError, Net::OpenTimeout, Net::ReadTimeout, SocketError, EOFError,
      Errno::ECONNRESET, Errno::ECONNREFUSED, Errno::EHOSTUNREACH, Errno::ETIMEDOUT, OpenSSL::SSL::SSLError ].freeze

    module_function

    # In development and tests there are no keys: a generated one lets the browser subscribe,
    # and nothing real is sent with it.
    def public_key
      ENV["VAPID_PUBLIC_KEY"].presence || (local_key.public_key if Rails.env.local?)
    end

    def deliver(subscription, message, urgent:)
      if Rails.env.development?
        Rails.logger.info("push not sent in development: subscription #{subscription.id}")
        return
      end

      WebPush.payload_send(message: message, endpoint: subscription.endpoint, p256dh: subscription.p256dh, auth: subscription.auth,
        vapid: vapid, ttl: TTL, urgency: urgent ? "high" : "normal", open_timeout: OPEN_TIMEOUT, read_timeout: READ_TIMEOUT)
    end

    def vapid
      return { subject: SUBJECT, public_key: local_key.public_key, private_key: local_key.private_key } if ENV["VAPID_PRIVATE_KEY"].blank? && Rails.env.local?

      { subject: ENV.fetch("VAPID_SUBJECT", SUBJECT), public_key: ENV.fetch("VAPID_PUBLIC_KEY"), private_key: ENV.fetch("VAPID_PRIVATE_KEY") }
    end

    def local_key
      @local_key ||= WebPush.generate_key
    end
  end
end
