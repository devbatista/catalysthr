module Billing
  # Sends a paid invoice's NFS-e to Asaas (RN-19-104, D-633). Asaas out of the air is tried
  # again 1, 5 and 15 minutes later (RN-19-109, P-19-34); the tries spent, the note shows
  # the error and the team is told (RN-19-108). Running again for a note already sent
  # changes nothing.
  class IssueServiceInvoiceJob < ApplicationJob
    WAITS = [ 1.minute, 5.minutes, 15.minutes ].freeze

    queue_as :default

    retry_on Asaas::Error, attempts: WAITS.size + 1, wait: ->(executions) { WAITS.fetch(executions - 1) } do |job, error|
      Rails.error.report(error)
      ServiceInvoices.fail!(job.arguments.first, I18n.t("billing.service_invoices.errors.unavailable"))
    end

    def perform(note)
      return unless FeatureFlags.enabled?(FeatureFlags::NFSE)

      ServiceInvoices.issue(note)
    end
  end
end
