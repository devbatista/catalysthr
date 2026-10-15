# Access e-mails: password recovery and unlock (RN-02-031, RN-02-033), sent on behalf
# of the brand (BrandSender). The links open the subdomain where they were asked for.
class UserMailer < Devise::Mailer
  include BrandSender

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
    @sender_name = @brand&.commercial_name || BrandSender::PLATFORM_NAME

    opts.merge(brand_headers(brand: @brand))
  end
end
