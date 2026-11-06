module Employments
  # Every morning, the notices of the experience's end and the passing to the next state
  # (RN-07-101, RN-07-102, D-648, D-653). A day it didn't run is covered by the next one.
  class ExperienceAlertsJob < ApplicationJob
    queue_as :default

    def perform
      return unless FeatureFlags.enabled?(FeatureFlags::ADMISSIONS)

      company_ids = Employment.with_experience_open(CrossCompany.scope(Employment, Company.all)).distinct.pluck(:company_id)
      Company.where(id: company_ids).find_each do |company|
        ActsAsTenant.with_tenant(company) do
          Employment.with_experience_open(Employment.all).find_each { |employment| Experience.check(employment) }
        end
      end
    end
  end
end
