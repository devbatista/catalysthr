module Employments
  # Activates the employments of the day, and of a day it didn't run (RN-07-085, D-648, D-653).
  # Every hour, because the day turns at a different hour in each unit's time zone; an
  # employment is seen until its unit's date arrives.
  class ActivateStartingJob < ApplicationJob
    queue_as :default

    def perform
      return unless FeatureFlags.enabled?(FeatureFlags::ADMISSIONS)

      latest = Date.current + 1
      company_ids = CrossCompany.scope(Employment, Company.all).pending.where(started_on: ..latest).distinct.pluck(:company_id)
      Company.where(id: company_ids).find_each do |company|
        ActsAsTenant.with_tenant(company) do
          Employment.pending.where(started_on: ..latest).find_each do |employment|
            Activate.call(employment) if employment.started_on <= employment.today
          end
        end
      end
    end
  end
end
