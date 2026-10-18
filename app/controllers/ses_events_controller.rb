# The SES events that SNS posts (spec 15, P-15-24, D-609), outside the areas: no sign-in,
# no session and no CSRF token, since the request comes from AWS. Only a message signed by
# SNS, verified with AWS's own verifier, from the app's topic, is accepted. The topic's
# subscription is confirmed here, at the address SNS gives, which must be AWS's.
class SesEventsController < ActionController::API
  SUBSCRIBE_HOST = /\Asns\.[a-z0-9-]+\.amazonaws\.com\z/
  # Keeps the downloaded certificates between requests.
  VERIFIER = Aws::SNS::MessageVerifier.new

  def create
    body = request.raw_post
    message = JSON.parse(body)
    return head(:forbidden) unless message.is_a?(Hash) && message["TopicArn"] == Rails.configuration.x.ses_events_topic_arn
    return head(:forbidden) unless VERIFIER.authentic?(body)

    case message["Type"]
    when "SubscriptionConfirmation" then return head(:forbidden) unless confirm(message["SubscribeURL"])
    when "Notification" then Notifications::SesEvents.handle(JSON.parse(message["Message"]))
    end
    head :ok
  rescue JSON::ParserError
    head :bad_request
  end

  private

  def confirm(url)
    uri = URI.parse(url.to_s)
    return false unless uri.scheme == "https" && uri.host.to_s.match?(SUBSCRIBE_HOST)

    Net::HTTP.get_response(uri).is_a?(Net::HTTPSuccess)
  rescue URI::InvalidURIError
    false
  end
end
