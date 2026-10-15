class ApplicationMailer < ActionMailer::Base
  # Platform sender, used while a brand has no verified e-mail domain (RN-01-040, D-160).
  PLATFORM_ADDRESS = "nao-responda@catalysthr.com.br"
  PLATFORM_NAME = "CatalystHR"

  default from: email_address_with_name(PLATFORM_ADDRESS, PLATFORM_NAME)
  layout "mailer"
end
