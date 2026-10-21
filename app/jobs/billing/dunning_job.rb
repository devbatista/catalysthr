module Billing
  # The daily dunning schedule (RN-19-050, D-624), after the PIX check, so a payment found
  # there counts. Running again changes nothing. Does nothing while billing is off (D-610).
  class DunningJob < ApplicationJob
    queue_as :default

    def perform(today = Date.current)
      return unless FeatureFlags.enabled?(FeatureFlags::BILLING)

      Dunning.run(today)
    end
  end
end
