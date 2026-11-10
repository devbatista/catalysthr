module Imports
  # "Liberar acesso de todos" in the background (P-07-06, D-668), so a large batch does not hold
  # the page; the import's page shows what is still waiting. Idempotent: an admission already
  # released is not released again, so running twice sends nothing twice.
  class ReleaseAdmissionsJob < ApplicationJob
    queue_as :imports

    def perform(import, by)
      ActsAsTenant.with_tenant(import.company) do
        _released, failed = AdmissionsRelease.new(import).call(by: by)
        Rails.logger.info("imports.release_admissions import=#{import.id} failed=#{failed.size}") if failed.any?
      end
    end
  end
end
