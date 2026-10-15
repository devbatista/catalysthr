class ApplicationMailer < ActionMailer::Base
  default from: email_address_with_name(BrandSender::PLATFORM_ADDRESS, BrandSender::PLATFORM_NAME)
  layout "mailer"
end
