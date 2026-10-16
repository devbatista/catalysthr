# Sender of the e-mails sent on behalf of a brand. They always leave from no-reply@:
# at the brand's domain once it is verified in SES, and at the platform's until then,
# with the brand's name and its support as the reply-to (RN-01-040, D-160, D-596,
# CA-01-008, CA-01-009). A partner's company with its own brand gets the partner's
# brand here, with its own name as the sender in the replace mode (P-01-18).
module BrandSender
  LOCAL_PART = "no-reply"
  PLATFORM_DOMAIN = "catalysthr.com.br"
  PLATFORM_ADDRESS = "#{LOCAL_PART}@#{PLATFORM_DOMAIN}"
  PLATFORM_NAME = "CatalystHR"

  private

  def brand_headers(brand:, sender_name: nil)
    name = sender_name || brand&.commercial_name || PLATFORM_NAME
    address = brand&.email_domain_verified? ? "#{LOCAL_PART}@#{brand.email_domain}" : PLATFORM_ADDRESS
    { from: email_address_with_name(address, name), reply_to: brand&.support_email.presence }.compact
  end
end
