module Announcements
  # Every 5 minutes (spec 15, section 8): puts up the scheduled notices whose time came and
  # whose attachment is clean, and ends the ones whose validity passed (RN-15-071, D-656).
  class PublishScheduledJob < ApplicationJob
    queue_as :notifications

    def perform
      each_company(->(base) { base.scheduled.where(publish_at: ..Time.current) }) do |announcement|
        Publish.call(announcement)
      end
      each_company(->(base) { base.published.where(expires_at: ..Time.current) }) do |announcement|
        announcement.update!(status: "expired")
      end
    end

    private

    # Finds the companies with notices to move, then moves each inside its company.
    def each_company(scope)
      company_ids = scope.call(CrossCompany.scope(Announcement, Company.all)).distinct.pluck(:company_id)
      Company.where(id: company_ids).find_each do |company|
        ActsAsTenant.with_tenant(company) { scope.call(Announcement.all).find_each { |announcement| yield announcement } }
      end
    end
  end
end
