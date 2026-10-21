module Billing
  # Reads in the API an order Mercado Pago's webhook told about and applies its status
  # (RN-19-046, CA-19-007): the notice only says which order changed. Running again, or
  # for an order that is not ours, changes nothing. Mercado Pago out of the air is tried
  # again with growing waits; what is still missing, the daily check finds (CA-19-008).
  class SyncOrderJob < ApplicationJob
    queue_as :default

    retry_on MercadoPago::Error, attempts: 5, wait: :polynomially_longer do |_job, error|
      Rails.error.report(error)
    end

    def perform(order_id)
      return unless FeatureFlags.enabled?(FeatureFlags::BILLING) && MercadoPago.configured?

      Pix.sync(MercadoPago.order(order_id))
    rescue MercadoPago::Error => e
      raise unless e.status == 404
    end
  end
end
