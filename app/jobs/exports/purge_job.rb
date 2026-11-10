module Exports
  # Daily: the full exports past their 7 days leave the storage and become expired, with the
  # password erased if nobody saw it (RN-18-073, P-18-22). The record stays, so the weekly
  # limit and the history still count it. Idempotent.
  class PurgeJob < ApplicationJob
    queue_as :imports

    def perform(now: Time.current)
      company_ids = CrossCompany.scope(CompanyExport, Company.all).where(status: "ready", expires_at: ...now).distinct.pluck(:company_id)
      Company.where(id: company_ids).find_each do |company|
        ActsAsTenant.with_tenant(company) do
          CompanyExport.where(status: "ready", expires_at: ...now).find_each do |export|
            export.parts.purge if export.parts.attached?
            export.update!(status: "expired", password: nil)
          end
        end
      end
    end
  end
end
