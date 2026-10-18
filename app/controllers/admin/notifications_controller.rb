module Admin
  # The bell in the CatalystHR admin (spec 15, RN-15-001).
  class NotificationsController < BaseController
    include NotificationInbox
  end
end
