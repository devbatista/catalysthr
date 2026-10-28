# Asaas's notices about the NFS-e (spec 19, RN-19-106, P-19-33, D-633), outside the areas:
# no sign-in, no session and no CSRF token, since the request comes from Asaas. Only a
# notice with the webhook's token, in `asaas-access-token`, is accepted (401 otherwise).
# The notice is not trusted as it is: the job reads the note in the API, so a repeated,
# late or forged notice changes nothing. Asaas takes any answer but 200 as a failure and
# stops the queue after 15 of them, so the answer goes out at once, and a notice that is
# not about a note is answered 200 too.
class AsaasWebhooksController < ActionController::API
  INVOICE_ID = /\A[A-Za-z0-9_]{1,64}\z/

  def create
    return head(:unauthorized) unless valid_token?

    event = params[:event].to_s
    note_id = params.dig(:invoice, :id).to_s
    Billing::SyncServiceInvoiceJob.perform_later(note_id) if event.start_with?("INVOICE_") && note_id.match?(INVOICE_ID)
    head :ok
  end

  private

  def valid_token?
    token = Rails.configuration.x.asaas_webhook_token
    received = request.headers["asaas-access-token"]
    token.present? && received.present? && ActiveSupport::SecurityUtils.secure_compare(token, received)
  end
end
