# Mercado Pago's Orders API answered by WebMock (D-622): no request leaves the test. The
# order follows the example of Mercado Pago's PIX page (spec/fixtures/files/mercado_pago).
module MercadoPagoStub
  TOKEN = "TEST-1234567890"
  SECRET = "segredo-do-webhook"
  ORDERS_URL = "https://api.mercadopago.com/v1/orders"

  def configure_mercado_pago
    Rails.configuration.x.mercado_pago_access_token = TOKEN
    Rails.configuration.x.mercado_pago_webhook_secret = SECRET
  end

  # The PIX order, with our reference and amount, and the status given.
  def mp_order(id: "ORD01HRYFWNYRE1MR1E60MW3X0T2P", external_reference: nil, amount_cents: 5_000, status: "action_required",
    status_detail: "waiting_transfer", paid_cents: nil)
    order = JSON.parse(file_fixture("mercado_pago/pix_order.json").read)
    amount = MoneyCents.decimal(amount_cents)
    order.merge!("id" => id, "external_reference" => external_reference, "total_amount" => amount, "status" => status,
      "status_detail" => status_detail)
    order["total_paid_amount"] = MoneyCents.decimal(paid_cents) if paid_cents
    order["transactions"]["payments"][0].merge!("amount" => amount, "status" => status, "status_detail" => status_detail)
    order
  end

  # Answers the creation with an order of its own for the reference sent.
  def stub_create_order(status: 201, **attributes)
    stub_request(:post, ORDERS_URL).with(headers: { "Authorization" => "Bearer #{TOKEN}" }).to_return do |request|
      body = JSON.parse(request.body)
      order = mp_order(id: mp_order_id(body["external_reference"]), external_reference: body["external_reference"],
        amount_cents: MoneyCents.parse(body["total_amount"]), **attributes)
      { status: status, body: order.to_json, headers: { "Content-Type" => "application/json" } }
    end
  end

  def mp_order_id(reference)
    "ORD#{reference.to_s.delete("-").upcase}"
  end

  def stub_get_order(order, status: 200)
    stub_request(:get, "#{ORDERS_URL}/#{order["id"]}").to_return(status: status, body: order.to_json,
      headers: { "Content-Type" => "application/json" })
  end

  # The `x-signature` Mercado Pago sends for the notice.
  def mp_signature(data_id, request_id, ts: Time.current.to_i, secret: SECRET)
    manifest = "id:#{data_id};request-id:#{request_id};ts:#{ts};"
    "ts=#{ts},v1=#{OpenSSL::HMAC.hexdigest("SHA256", secret, manifest)}"
  end
end

RSpec.configure do |config|
  config.include MercadoPagoStub
  config.after do
    Rails.configuration.x.mercado_pago_access_token = nil
    Rails.configuration.x.mercado_pago_webhook_secret = nil
  end
end
