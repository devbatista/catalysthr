module Billing
  # The daily check of the NFS-e in Asaas's API, for a lost webhook or a lost job
  # (RN-19-106, P-19-33, D-633). Running again changes nothing. Does nothing while the notes
  # are off or without the API key.
  class ServiceInvoiceReconcileJob < ApplicationJob
    queue_as :default

    def perform
      return unless FeatureFlags.enabled?(FeatureFlags::NFSE) && Asaas.configured?

      ServiceInvoices.reconcile
    end
  end
end
