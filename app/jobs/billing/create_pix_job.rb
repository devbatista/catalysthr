module Billing
  # Generates the PIX of an invoice just issued (RN-19-042, D-622). Mercado Pago out of the
  # air is tried again with growing waits; when every try fails, the error is reported and
  # the PIX is generated when the payer opens the invoice. Running again changes nothing
  # while the PIX is valid. Does nothing while billing is off (D-610) or without the
  # account's token.
  class CreatePixJob < ApplicationJob
    queue_as :default

    retry_on MercadoPago::Error, attempts: 5, wait: :polynomially_longer do |_job, error|
      Rails.error.report(error)
    end

    def perform(invoice)
      return unless FeatureFlags.enabled?(FeatureFlags::BILLING) && MercadoPago.configured?

      Pix.ensure_for(invoice)
    end
  end
end
