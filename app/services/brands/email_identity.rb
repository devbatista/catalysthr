module Brands
  # The brand's e-mail domain as an identity in SES, in São Paulo (RN-01-040, D-596):
  # Easy DKIM, with the platform's configuration set as the default, and a MAIL FROM of
  # its own, bounce.<domain>, for SPF.
  module EmailIdentity
    MAIL_FROM_PREFIX = "bounce"
    SPF = "v=spf1 include:amazonses.com ~all"
    # When SES does not tell the zone of the DKIM records.
    DEFAULT_SIGNING_ZONE = "dkim.amazonses.com"

    # The domain is already an identity of the account, outside this brand.
    class AlreadyExists < StandardError; end
    # SES did not answer, refused the call or has no credentials. Already reported.
    class Unavailable < StandardError; end

    module_function

    # Creates the identity and returns the DNS records to publish.
    def create(domain)
      response = client.create_email_identity(email_identity: domain, configuration_set_name: configuration_set)
      begin
        client.put_email_identity_mail_from_attributes(email_identity: domain,
          mail_from_domain: mail_from(domain), behavior_on_mx_failure: "USE_DEFAULT_VALUE")
      rescue Aws::Errors::ServiceError, Seahorse::Client::NetworkingError
        delete(domain)
        raise
      end
      records(domain, response.dkim_attributes)
    rescue Aws::SESV2::Errors::AlreadyExistsException
      raise AlreadyExists
    rescue Aws::Errors::ServiceError, Aws::Errors::MissingCredentialsError, Seahorse::Client::NetworkingError => error
      unavailable(error)
    end

    # "verified" when the DKIM and the MAIL FROM are confirmed, "failed" when SES gave up
    # on either, "pending" otherwise. A deleted identity counts as failed.
    def status(domain)
      identity = client.get_email_identity(email_identity: domain)
      statuses = [ identity.dkim_attributes&.status, identity.mail_from_attributes&.mail_from_domain_status ]
      if statuses.all?("SUCCESS") then "verified"
      elsif statuses.include?("FAILED") then "failed"
      else "pending"
      end
    rescue Aws::SESV2::Errors::NotFoundException
      "failed"
    rescue Aws::Errors::ServiceError, Aws::Errors::MissingCredentialsError, Seahorse::Client::NetworkingError => error
      unavailable(error)
    end

    def delete(domain)
      client.delete_email_identity(email_identity: domain)
    rescue Aws::SESV2::Errors::NotFoundException
      nil
    rescue Aws::Errors::ServiceError, Aws::Errors::MissingCredentialsError, Seahorse::Client::NetworkingError => error
      unavailable(error)
    end

    def records(domain, dkim)
      zone = dkim&.signing_hosted_zone.presence || DEFAULT_SIGNING_ZONE
      Array(dkim&.tokens).map { |token| { "type" => "CNAME", "name" => "#{token}._domainkey.#{domain}", "value" => "#{token}.#{zone}" } } + [
        { "type" => "MX", "name" => mail_from(domain), "value" => "10 feedback-smtp.#{region}.amazonses.com" },
        { "type" => "TXT", "name" => mail_from(domain), "value" => SPF }
      ]
    end

    def mail_from(domain)
      "#{MAIL_FROM_PREFIX}.#{domain}"
    end

    def unavailable(error)
      Rails.error.report(error, handled: true, context: { service: "ses" })
      raise Unavailable
    end

    def client
      Aws::SESV2::Client.new(region: region)
    end

    def region
      ENV.fetch("AWS_REGION", "sa-east-1")
    end

    def configuration_set
      ENV.fetch("SES_CONFIGURATION_SET", "catalysthr-padrao")
    end
  end
end
