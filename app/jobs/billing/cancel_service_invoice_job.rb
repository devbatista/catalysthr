module Billing
  # Asks Asaas to cancel a refunded invoice's NFS-e (RN-19-110, D-565, CA-19-014). Asaas out
  # of the air is tried again 1, 5 and 15 minutes later, like the issuing (RN-19-109); the
  # tries spent, the cancellation shows as refused and the team is told (P-19-35). Running
  # again for a note no longer being cancelled changes nothing.
  class CancelServiceInvoiceJob < ApplicationJob
    queue_as :default

    retry_on Asaas::Error, attempts: IssueServiceInvoiceJob::WAITS.size + 1,
      wait: ->(executions) { IssueServiceInvoiceJob::WAITS.fetch(executions - 1) } do |job, error|
      Rails.error.report(error)
      ServiceInvoices.deny_cancel!(job.arguments.first, I18n.t("billing.service_invoices.errors.cancel_unavailable"))
    end

    def perform(note)
      return unless FeatureFlags.enabled?(FeatureFlags::NFSE)

      ServiceInvoices.cancel(note)
    end
  end
end
