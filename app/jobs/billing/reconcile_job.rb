module Billing
  # The daily check of the pending PIX in Mercado Pago's API, for a lost webhook (RN-19-046,
  # CA-19-008). Running again changes nothing: a paid PIX stays paid. Does nothing while
  # billing is off (D-610) or without the account's token.
  class ReconcileJob < ApplicationJob
    queue_as :default

    def perform
      return unless FeatureFlags.enabled?(FeatureFlags::BILLING) && MercadoPago.configured?

      Pix.reconcile
    end
  end
end
