module Billing
  # Reads in the API a note Asaas's webhook told about and applies its status (RN-19-106,
  # D-633). Running again, or for a note that is not ours, changes nothing. Asaas out of
  # the air is tried again with growing waits; what is still missing, the daily check finds.
  class SyncServiceInvoiceJob < ApplicationJob
    queue_as :default

    retry_on Asaas::Error, attempts: 5, wait: :polynomially_longer do |_job, error|
      Rails.error.report(error)
    end

    def perform(asaas_invoice_id)
      return unless FeatureFlags.enabled?(FeatureFlags::NFSE) && Asaas.configured?

      ServiceInvoices.sync(Asaas.invoice(asaas_invoice_id))
    rescue Asaas::Error => e
      raise unless e.status == 404
    end
  end
end
