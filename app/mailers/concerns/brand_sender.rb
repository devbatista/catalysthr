# Sender of the e-mails sent on behalf of a brand. Until the brand has a verified
# e-mail domain, they leave from the platform address with the brand's name, and the
# brand's support is the reply-to (RN-01-040, D-160, CA-01-008).
module BrandSender
  PLATFORM_ADDRESS = "nao-responda@catalysthr.com.br"
  PLATFORM_NAME = "CatalystHR"

  private

  def brand_headers(brand:, sender_name: nil)
    name = sender_name || brand&.commercial_name || PLATFORM_NAME
    { from: email_address_with_name(PLATFORM_ADDRESS, name), reply_to: brand&.support_email.presence }.compact
  end
end
