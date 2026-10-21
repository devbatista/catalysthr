require "rails_helper"

# Spec 19, RN-19-046 and P-19-29 (D-622): our own client of Mercado Pago's Orders API and
# the webhook's signature, as the official SDKs check it.
RSpec.describe Billing::MercadoPago do
  around { |example| travel_to(Time.zone.local(2026, 10, 15, 10)) { example.run } }

  before { configure_mercado_pago }

  describe ".valid_signature?" do
    let(:data_id) { "ORD01M28P44G5FG8RJPM579EH56FV" }

    it "accepts the HMAC-SHA256 of id, request-id and ts with the account's secret" do
      expect(described_class.valid_signature?(mp_signature(data_id, "req-1"), "req-1", data_id)).to be(true)
    end

    it "refuses another secret, another order or another request" do
      expect(described_class.valid_signature?(mp_signature(data_id, "req-1", secret: "outro"), "req-1", data_id)).to be(false)
      expect(described_class.valid_signature?(mp_signature(data_id, "req-1"), "req-1", "ORD999")).to be(false)
      expect(described_class.valid_signature?(mp_signature(data_id, "req-1"), "req-2", data_id)).to be(false)
    end

    it "keeps the id's case, as the official SDKs do" do
      expect(described_class.valid_signature?(mp_signature(data_id, "req-1"), "req-1", data_id.downcase)).to be(false)
    end

    it "leaves an empty pair out of the signed text" do
      ts = Time.current.to_i
      signature = "ts=#{ts},v1=#{OpenSSL::HMAC.hexdigest("SHA256", MercadoPagoStub::SECRET, "id:#{data_id};ts:#{ts};")}"

      expect(described_class.valid_signature?(signature, nil, data_id)).to be(true)
    end

    it "refuses a notice older than 5 minutes, a malformed header and a missing secret" do
      expect(described_class.valid_signature?(mp_signature(data_id, "req-1", ts: 6.minutes.ago.to_i), "req-1", data_id)).to be(false)
      expect(described_class.valid_signature?("lixo", "req-1", data_id)).to be(false)
      Rails.configuration.x.mercado_pago_webhook_secret = nil
      expect(described_class.valid_signature?(mp_signature(data_id, "req-1"), "req-1", data_id)).to be(false)
    end
  end

  describe "the calls" do
    it "sends the token and the idempotency key, and returns the order" do
      stub = stub_create_order

      order = described_class.create_order({ total_amount: "50.00", external_reference: "ref" }, idempotency_key: "key-1")

      expect(order).to include("id" => mp_order_id("ref"), "status" => "action_required")
      expect(stub.with(headers: { "X-Idempotency-Key" => "key-1" })).to have_been_requested
    end

    it "raises with Mercado Pago's status and error code, never the body" do
      stub_request(:get, "#{MercadoPagoStub::ORDERS_URL}/ORD1").to_return(status: 404,
        body: { errors: [ { code: "order_not_found", message: "Order not found" } ] }.to_json)

      expect { described_class.order("ORD1") }.to raise_error(described_class::Error, "Mercado Pago answered 404 (order_not_found)") { |error|
        expect(error.status).to eq(404)
      }
    end

    it "raises when Mercado Pago does not answer" do
      stub_request(:get, "#{MercadoPagoStub::ORDERS_URL}/ORD1").to_timeout

      expect { described_class.order("ORD1") }.to raise_error(described_class::Error, /unavailable/)
    end

    it "calls nothing without the account's token" do
      Rails.configuration.x.mercado_pago_access_token = nil

      expect { described_class.order("ORD1") }.to raise_error(described_class::Error, /not configured/)
    end
  end
end
