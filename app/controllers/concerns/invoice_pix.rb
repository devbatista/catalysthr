# The PIX shown on an invoice to whoever pays it, the financial responsible (RN-19-042,
# RN-19-044, D-622): the one still valid, or a new one once it has expired. An impersonate
# is read only and calls no outside service (RN-02-080), so it only shows a valid one.
module InvoicePix
  extend ActiveSupport::Concern

  private

  def load_pix(invoice)
    return unless invoice.payable?

    @pix = if impersonating? || !Billing::MercadoPago.configured?
      invoice.payments.pix.pending.order(:created_at).last&.then { |payment| payment if payment.live? }
    else
      Billing::Pix.ensure_for(invoice)
    end
  rescue Billing::MercadoPago::Error => e
    Rails.error.report(e, context: { invoice_id: invoice.id })
  end
end
