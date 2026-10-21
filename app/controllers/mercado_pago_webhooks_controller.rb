# Mercado Pago's notices (spec 19, RN-19-046, D-622), outside the areas: no sign-in, no
# session and no CSRF token, since the request comes from Mercado Pago. Only a notice signed
# with the account's secret is accepted (401 otherwise, as Mercado Pago's guide says). The
# notice only says which order changed: the job reads it in the API, so the answer goes
# out at once, well within Mercado Pago's 22 seconds.
class MercadoPagoWebhooksController < ActionController::API
  ORDER_ID = /\A[A-Za-z0-9]{1,64}\z/

  def create
    data_id = request.query_parameters["data.id"]
    signed = Billing::MercadoPago.valid_signature?(request.headers["x-signature"], request.headers["x-request-id"], data_id)
    return head(:unauthorized) unless signed

    Billing::SyncOrderJob.perform_later(data_id) if request.query_parameters["type"] == "order" && data_id.to_s.match?(ORDER_ID)
    head :ok
  end
end
