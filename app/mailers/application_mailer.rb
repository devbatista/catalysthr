class ApplicationMailer < ActionMailer::Base
  default from: email_address_with_name(BrandSender::PLATFORM_ADDRESS, BrandSender::PLATFORM_NAME)
  layout "mailer"

  # No e-mail goes to an address with a permanent bounce (RN-15-083, D-609): SES would
  # drop it anyway. The screens that send tell it before; this is the last guard.
  after_action :skip_bounced_recipients

  private

  def skip_bounced_recipients
    addresses = Array(message.to)
    bounced = User.email_bounced.where(email: addresses).pluck(:email)
    return if bounced.empty?

    message.to = addresses - bounced
    message.perform_deliveries = false if message.to.blank?
  end
end
