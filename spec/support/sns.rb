# Messages signed like SNS's, with a certificate made here and served by WebMock at an
# address that looks like AWS's (spec 15, P-15-24, D-609). No call reaches AWS.
module SnsHelpers
  CERT_URL = "https://sns.sa-east-1.amazonaws.com/SimpleNotificationService-test.pem".freeze
  TOPIC_ARN = "arn:aws:sns:sa-east-1:464986173446:catalysthr-ses-eventos".freeze

  def self.key
    @key ||= OpenSSL::PKey::RSA.new(2048)
  end

  def self.certificate
    @certificate ||= OpenSSL::X509::Certificate.new.tap do |cert|
      cert.version = 2
      cert.serial = 1
      cert.subject = cert.issuer = OpenSSL::X509::Name.parse("/CN=sns.amazonaws.com")
      cert.public_key = key.public_key
      cert.not_before = Time.now - 3600
      cert.not_after = Time.now + 3600
      cert.sign(key, OpenSSL::Digest.new("SHA256"))
    end
  end

  def stub_sns_certificate
    stub_request(:get, CERT_URL).to_return(status: 200, body: SnsHelpers.certificate.to_pem)
  end

  # A signed SNS message (SignatureVersion 2, SHA256), as JSON.
  def sns_message(type: "Notification", topic: TOPIC_ARN, message: nil, subscribe_url: nil, key: SnsHelpers.key)
    body = { "Type" => type, "MessageId" => SecureRandom.uuid, "TopicArn" => topic, "Message" => message.to_json,
      "Timestamp" => Time.current.utc.iso8601, "SignatureVersion" => "2", "SigningCertURL" => CERT_URL }
    if subscribe_url
      body["SubscribeURL"] = subscribe_url
      body["Token"] = "token"
      body["Message"] = "You have chosen to subscribe"
    end
    canonical = %w[Message MessageId Subject SubscribeURL Timestamp Token TopicArn Type]
      .filter_map { |name| "#{name}\n#{body[name]}\n" if body[name].present? }.join
    body["Signature"] = Base64.strict_encode64(key.sign(OpenSSL::Digest.new("SHA256"), canonical))
    body.to_json
  end

  def ses_event(type, message_id: "ses-1", **details)
    { "eventType" => type, "mail" => { "messageId" => message_id } }.merge(details.deep_stringify_keys)
  end

  def post_sns(body)
    post "/webhooks/ses-events", params: body, headers: { "Content-Type" => "text/plain; charset=UTF-8" }
  end
end

RSpec.configure do |config|
  config.include SnsHelpers, type: :request
end
