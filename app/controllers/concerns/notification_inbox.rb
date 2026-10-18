# The bell (spec 15, RN-15-001): the person's notices of the last 90 days in the area being
# accessed, the unread count the page fetches every 60 seconds, and opening a notice,
# which marks it read and goes to its page. An impersonate only looks: nothing is marked
# read (RN-02-084).
module NotificationInbox
  extend ActiveSupport::Concern

  # The most recent ones; older ones stay until they leave the bell.
  LIST_LIMIT = 100

  def index
    authorize! :read, Notification
    @notifications = visible_notifications.in_bell.newest_first.limit(LIST_LIMIT)
  end

  def show
    notification = visible_notifications.find(params[:id])
    authorize! :read, notification
    notification.read! unless impersonating?
    redirect_to notification.path
  end

  def unread_count
    authorize! :read, Notification
    render json: { count: visible_notifications.in_bell.unread.count }
  end

  private

  def visible_notifications
    Notification.visible_to(current_user, area: Current.area, brand: Current.brand)
  end
end
