# The bell in the top bar and the list of notices, in the panel and in the admin (spec 15,
# RN-15-001).
module NotificationsHelper
  def bell_unread_count
    @bell_unread_count ||= Notification.visible_to(current_user, area: Current.area, brand: Current.brand).in_bell.unread.count
  end

  def bell_path
    return portal_notifications_path if portal_page?

    Current.area == :admin ? admin_notifications_path : notifications_path
  end

  def bell_count_path
    Current.area == :admin ? unread_count_admin_notifications_path : unread_count_notifications_path
  end

  def open_notification_path(notification)
    return portal_notification_path(notification) if portal_page?

    Current.area == :admin ? admin_notification_path(notification) : notification_path(notification)
  end

  # The portal's pages keep the person in the portal (spec 16, D-645).
  def portal_page?
    controller_path.start_with?("panel/portal")
  end

  def bell_label(count)
    count.zero? ? t("notifications.bell.label") : t("notifications.bell.label_unread", count: count)
  end

  # The e-mail that bounced or complained, next to the address wherever it is shown
  # (RN-15-083, D-609).
  def email_status_pill(user)
    return if user.email.blank? || user.email_valid?

    tag.span(t("notifications.email_status.#{user.email_status}", date: l(user.email_status_at.to_date)),
      class: class_names("pill", "pill-bad" => user.email_bounced?, "pill-warn" => user.email_complained?))
  end
end
