# The e-mail of a notice (spec 15, RN-15-002, P-15-02): on behalf of the brand, with its
# logo and color, the notice's text, a button that opens it in the platform and, in the
# footer, the way to the preferences. A
# partner's company in replace mode shows its own name (P-01-18); its logo is only served
# to signed-in people, so the header is the name. Without a brand, CatalystHR.
class NotificationMailer < ApplicationMailer
  include BrandSender

  layout "mailer_notice"

  def notice(notification)
    @notification = notification
    @user = notification.recipient_user
    @brand = notification.brand
    @sender_name = notification.recipient_membership&.sender_name(@brand) || @brand&.commercial_name || PLATFORM_NAME
    @color = @brand&.colors&.fetch(:primary) || Brand::DEFAULT_COLORS[:primary]
    @logo_url = logo_url
    @url = notification.url
    @preferences_url = preferences_url

    mail(to: @user.email, subject: notification.title, **brand_headers(brand: @brand, sender_name: @sender_name))
  end

  private

  # "Minhas notificações", where the panel's people choose the channels (RN-15-002).
  def preferences_url
    return if @notification.area == "admin" || @brand&.active_subdomain.nil?

    @brand.panel_url("/notification-preferences/edit")
  end

  def logo_url
    return unless @brand&.logo_light&.attached? && @brand.active_subdomain && @sender_name == @brand.commercial_name

    @brand.panel_url("/brand-assets/logo_light", v: @brand.logo_light.blob_id)
  end
end
