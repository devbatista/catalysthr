module Ai
  # Every hour, the 80% and 100% notices of the month's AI credits (spec 14, RN-14-112,
  # CA-14-011). Idempotent: each threshold is told once in the month. The daily cap is checked
  # at each call (Ai::DailyCap), not here.
  class UsageAlertsJob < ApplicationJob
    queue_as :default

    def perform
      return unless FeatureFlags.enabled?(FeatureFlags::AI)

      UsageAlerts.call
    end
  end
end
