module Panel
  module Portal
    # The bell in the portal (spec 15, RN-15-001; spec 16, D-645): the same notices of the
    # panel, opened in the portal's frame.
    class NotificationsController < BaseController
      include NotificationInbox
    end
  end
end
