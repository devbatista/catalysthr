module Billing
  # Every day, before the dunning: the cancellations whose day passed go into closing, and
  # the partners' portfolios get the 30 days' notice (RN-19-062, RN-19-063, D-625). Running
  # again changes nothing. Does nothing while billing is off (D-610).
  class CancellationJob < ApplicationJob
    queue_as :default

    def perform(today = Date.current)
      return unless FeatureFlags.enabled?(FeatureFlags::BILLING)

      Cancellation.apply_due(today)
    end
  end
end
