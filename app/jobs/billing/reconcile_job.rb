module Billing
  # The daily check of the pending PIX in Mercado Pago's API, for a lost webhook (RN-19-046,
  # CA-19-008), and then the checkout's invoices of earlier days still unpaid, voided
  # (RN-19-033, D-622). Running again changes nothing: a paid PIX stays paid. Does nothing
  # while billing is off (D-610); without the account's token, only the voiding runs.
  class ReconcileJob < ApplicationJob
    queue_as :default

    def perform(today = Date.current)
      return unless FeatureFlags.enabled?(FeatureFlags::BILLING)

      Pix.reconcile if MercadoPago.configured?
      Checkout.void_unpaid(today)
    end
  end
end
