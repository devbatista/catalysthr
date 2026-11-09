module Imports
  # Daily: 90 days after the sending, the file and the lines' data leave; the counts and the
  # messages stay, without the values (RN-18-010, P-18-07). What undoing needs leaves too, so
  # the import can no longer be undone (D-665). Idempotent.
  class PurgeJob < ApplicationJob
    queue_as :imports

    def perform
      cutoff = DataImport::RETENTION.ago
      company_ids = CrossCompany.scope(DataImport, Company.all).where(purged_at: nil, created_at: ...cutoff).distinct.pluck(:company_id)
      Company.where(id: company_ids).find_each do |company|
        ActsAsTenant.with_tenant(company) do
          DataImport.where(purged_at: nil, created_at: ...cutoff).find_each { |import| purge(import) }
        end
      end
    end

    private

    def purge(import)
      import.file.purge if import.file.attached?
      import.rows.find_each do |row|
        row.update!(payload: nil, diff: nil, undo_data: nil, issues: row.issues.map { |issue| issue.slice("column", "message") })
      end
      import.update!(purged_at: Time.current)
    end
  end
end
