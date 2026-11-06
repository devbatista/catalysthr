# The push on the page (spec 15, D-654): only with the flag and the keys, and never in an
# impersonate or a support entry, which only look.
module PushHelper
  def push_available?
    user_signed_in? && !impersonating? && Current.support_access.nil? && FeatureFlags.enabled?(FeatureFlags::PUSH_NOTIFICATIONS) &&
      Notifications::PushSender.public_key.present?
  end

  # data-sync, on the first page of the session, tells the browser to send its subscription,
  # which passes it to who signed in and picks up an address the browser renewed.
  def push_meta_tag
    return unless push_available?

    first_page = !session[:push_synced]
    session[:push_synced] = true
    tag.meta(name: "push-public-key", content: Notifications::PushSender.public_key, data: { sync: first_page })
  end
end
