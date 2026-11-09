module Announcements
  # Puts a scheduled notice on the board when its time comes and its attachment is clean
  # (RN-15-071, D-656), and tells its audience (RN-15-074). An attachment with a virus sends
  # the notice back to the drafts: the screen says why, and nothing goes up. A notice whose
  # validity passed while it waited ends without going up. Runs once per notice, whoever
  # comes first: the form, the scan or the job every 5 minutes.
  module Publish
    module_function

    def call(announcement)
      # With the board's flag off, what was scheduled waits (D-656).
      return false unless FeatureFlags.enabled?(FeatureFlags::ANNOUNCEMENTS)

      published = announcement.with_lock do
        next false unless announcement.scheduled? && announcement.publish_at <= Time.current

        case announcement.scan_status
        when "scanning" then next false
        when "infected"
          announcement.update!(status: "draft", publish_at: nil)
          next false
        end
        if announcement.expires_at <= Time.current
          announcement.update!(status: "expired")
          next false
        end
        announcement.update!(status: "published", published_at: Time.current)
      end
      NotifyJob.perform_later(announcement) if published
      published
    end
  end
end
