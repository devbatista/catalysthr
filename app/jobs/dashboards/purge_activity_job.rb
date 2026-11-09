module Dashboards
  # Daily: deletes the lines of "Atividade recente" older than 90 days (D-657). The panel
  # shows only the last 20; the audit stays in PaperTrail and access_events. Idempotent.
  class PurgeActivityJob < ApplicationJob
    queue_as :default

    def perform
      cutoff = ActivityEvent::RETENTION.ago
      company_ids = CrossCompany.scope(ActivityEvent, Company.all).where(occurred_at: ...cutoff).distinct.pluck(:company_id)
      Company.where(id: company_ids).find_each do |company|
        ActsAsTenant.with_tenant(company) { ActivityEvent.where(occurred_at: ...cutoff).in_batches.delete_all }
      end
    end
  end
end
