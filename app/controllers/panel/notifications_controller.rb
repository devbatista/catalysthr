module Panel
  # The bell in the brand's panel (spec 15, RN-15-001).
  class NotificationsController < BaseController
    include NotificationInbox
  end
end
