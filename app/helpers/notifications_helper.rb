# The bell in the top bar and the list of notices, in the panel and in the admin (spec 15,
# RN-15-001).
module NotificationsHelper
  def bell_unread_count
    @bell_unread_count ||= Notification.visible_to(current_user, area: Current.area, brand: Current.brand).in_bell.unread.count
  end

  def bell_path
    Current.area == :admin ? admin_notifications_path : notifications_path
  end

  def bell_count_path
    Current.area == :admin ? unread_count_admin_notifications_path : unread_count_notifications_path
  end

  def open_notification_path(notification)
    Current.area == :admin ? admin_notification_path(notification) : notification_path(notification)
  end

  def bell_label(count)
    count.zero? ? t("notifications.bell.label") : t("notifications.bell.label_unread", count: count)
  end
end
