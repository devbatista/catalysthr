# Access e-mails: password recovery and unlock (RN-02-031, RN-02-033). They leave from
# the platform domain with the brand's name and the brand's support as reply-to
# (RN-01-040, D-160), and the links open the subdomain where they were asked for.
class UserMailer < Devise::Mailer
  default template_path: "user_mailer"
  layout "mailer"
  # Access codes and security notices (RN-20-011).
  self.deliver_later_queue_name = :critical

  def reset_password_instructions(record, token, opts = {})
    super(record, token, prepare(opts))
  end

  def unlock_instructions(record, token, opts = {})
    super(record, token, prepare(opts))
  end

  private

  def prepare(opts)
    opts = opts.symbolize_keys
    @url_options = opts.delete(:url_options).to_h.symbolize_keys
    @brand = Brand.find_by(id: opts.delete(:brand_id))
    @sender_name = @brand&.commercial_name || ApplicationMailer::PLATFORM_NAME

    opts[:from] = email_address_with_name(ApplicationMailer::PLATFORM_ADDRESS, @sender_name)
    opts[:reply_to] = @brand.support_email if @brand&.support_email.present?
    opts
  end
end
