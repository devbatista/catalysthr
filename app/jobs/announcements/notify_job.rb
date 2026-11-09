module Announcements
  # Tells the audience of a notice just put on the board (RN-15-074, CA-15-011): the bell, the
  # e-mail with the title and the text, and the push, by each person's choices and quiet
  # hours. Only who is in the audience when it goes up, with access to the portal; who joins
  # later finds it on the board (D-656). Running again makes no second notice (RN-15-085).
  class NotifyJob < ApplicationJob
    queue_as :notifications

    def perform(announcement)
      return unless announcement.live?

      announcement.audience_filter.members.includes(membership: :user).find_each do |profile|
        membership = profile.membership
        Notifications.notify!("announcements.published", user: membership.user, membership: membership, company: announcement.company,
          subject: announcement, path: "/portal/announcements/#{announcement.id}", title: announcement.title, body: announcement.body)
      end
    end
  end
end
