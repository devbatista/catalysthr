# SES answers stubbed by the SDK itself: no request leaves the test (P-14-35).
module SesStub
  TOKENS = %w[tok1abc tok2def tok3ghi].freeze

  def stub_ses(**responses)
    defaults = {
      create_email_identity: { dkim_attributes: { tokens: TOKENS, signing_hosted_zone: "dkim.sa-east-1.amazonses.com" } },
      put_email_identity_mail_from_attributes: {},
      delete_email_identity: {}
    }
    client = Aws::SESV2::Client.new(region: "sa-east-1", stub_responses: defaults.merge(responses))
    allow(Brands::EmailIdentity).to receive(:client).and_return(client)
    client
  end

  def ses_identity(dkim:, mail_from:)
    { dkim_attributes: { status: dkim }, mail_from_attributes: { mail_from_domain: "bounce.x", mail_from_domain_status: mail_from,
      behavior_on_mx_failure: "USE_DEFAULT_VALUE" } }
  end
end

RSpec.configure { |config| config.include SesStub }
