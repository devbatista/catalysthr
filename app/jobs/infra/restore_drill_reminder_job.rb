module Infra
  # Every 3 months: reminds the superadmins of the restore drill (RN-20-046, D-627), with
  # the date of the last one. Idempotent: one notice per quarter.
  class RestoreDrillReminderJob < ApplicationJob
    queue_as :default

    def perform(today = Date.current)
      last = BackupRun.restore_drill.succeeded.latest_first.first
      quarter = "#{today.year}-T#{((today.month - 1) / 3) + 1}"
      User.superadmin.active.find_each do |user|
        Notifications.notify!("platform.restore_drill_due", user: user, area: "admin", path: "/", variant: (last ? "since" : "never"),
          dedup_key: "platform.restore_drill_due/#{quarter}", date: (I18n.l(last.started_at.to_date) if last))
      end
    end
  end
end
