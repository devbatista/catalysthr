module Notifications
  # The SES events that SNS posts to the app (spec 15, RN-15-080, RN-15-083, P-15-24,
  # P-15-26, D-609). Idempotent: SNS may deliver the same event twice.
  # - Delivery: the notice's delivery is delivered.
  # - Permanent bounce: the delivery fails and the address is marked invalid, which stops
  #   every e-mail to it, and the HR of the person's scope is told (CA-15-009). A
  #   temporary bounce changes nothing; SES keeps trying.
  # - Complaint: the address stops getting the optional notices.
  # The addresses are never logged or stored in the deliveries.
  module SesEvents
    module_function

    def handle(event)
      deliveries = deliveries_of(event)
      case event["eventType"] || event["notificationType"]
      when "Delivery"
        deliveries.select(&:sent?).each { |delivery| delivery.update!(status: "delivered", delivered_at: Time.current) }
      when "Bounce"
        return unless event.dig("bounce", "bounceType") == "Permanent"

        deliveries.each { |delivery| delivery.update!(status: "failed", failed_reason: "bounce") }
        addresses(event.dig("bounce", "bouncedRecipients")).each { |address| mark(address, "bounced") }
      when "Complaint"
        addresses(event.dig("complaint", "complainedRecipients")).each { |address| mark(address, "complained") }
      end
    end

    # One e-mail is one delivery, or all those of a daily digest (D-655).
    def deliveries_of(event)
      message_id = event.dig("mail", "messageId")
      return [] unless message_id

      delivery = NotificationDelivery.find_by(provider_message_id: message_id)
      delivery ? [ delivery ] : NotificationDigest.find_by(provider_message_id: message_id)&.deliveries.to_a
    end

    def addresses(recipients)
      Array(recipients).filter_map { |recipient| recipient["emailAddress"].to_s.strip.downcase.presence }
    end

    # A bounce wins over a complaint; the same status again changes nothing.
    def mark(address, status)
      user = User.find_by(email: address)
      return if user.nil? || user.email_status == status || user.email_bounced?

      user.update!(email_status: status, email_status_at: Time.current)
      EmailInvalidNotice.call(user) if status == "bounced"
    end
  end
end
