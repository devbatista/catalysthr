require "rails_helper"

# Spec 19, RN-19-042, RN-19-046 and RN-19-053 (CA-19-007, CA-19-008, D-622): the invoice's
# PIX in Mercado Pago's Orders API, valid until the end of the due date and generated again
# once it expires; the payment applied by the webhook or by the daily check.
RSpec.describe Billing::Pix do
  include ActiveJob::TestHelper

  let(:company) { create(:company, name: "Metalúrgica Serra Azul") }
  let(:subscription) { contract_for(company) }
  let(:account) { subscription.billing_account }
  let(:invoice) { Billing::Invoicing.issue_due(subscription, Date.current, lead: 0).sole }

  around { |example| travel_to(Time.zone.local(2026, 10, 15, 10)) { example.run } }

  before do
    Flipper.enable(FeatureFlags::BILLING)
    configure_mercado_pago
    account.update!(billing_email: "financeiro@serraazul.example")
  end

  describe ".ensure_for" do
    it "creates the PIX order, valid until the end of the due date (RN-19-042)" do
      stub = stub_create_order

      payment = described_class.ensure_for(invoice)

      expect(payment).to have_attributes(payment_method: "pix", status: "pending", amount_cents: 30_000,
        provider_order_id: mp_order_id(payment.id), provider_payment_id: "PAY01HRYFXQ53Q3JPEC48MYWMR0TE",
        raw_status: "action_required/waiting_transfer", ticket_url: start_with("https://www.mercadopago.com.br/"))
      expect(payment.qr_code).to start_with("000201")
      expect(payment.expires_at).to eq(Time.zone.local(2026, 10, 15, 23, 59, 59))
      expect(stub.with(headers: { "X-Idempotency-Key" => payment.idempotency_key }, body: {
        type: "online", processing_mode: "automatic", total_amount: "300.00", external_reference: payment.id,
        payer: { email: "financeiro@serraazul.example" },
        transactions: { payments: [ { amount: "300.00", payment_method: { id: "pix", type: "bank_transfer" },
          expiration_time: "PT13H59M59S" } ] }
      })).to have_been_requested
    end

    it "keeps the PIX while it is valid" do
      stub = stub_create_order
      first = described_class.ensure_for(invoice)

      travel 13.hours
      expect(described_class.ensure_for(invoice)).to eq(first)
      expect(stub).to have_been_requested.once
    end

    it "generates a new PIX for the invoice past due, valid until the end of the day (D-622)" do
      stub_create_order
      first = described_class.ensure_for(invoice)

      travel_to(Time.zone.local(2026, 11, 4, 8))
      second = described_class.ensure_for(invoice)

      expect(second).not_to eq(first)
      expect(second.expires_at).to eq(Time.zone.local(2026, 11, 4, 23, 59, 59))
    end

    it "gives at least 30 minutes, Mercado Pago's shortest PIX" do
      stub = stub_create_order
      travel_to(Time.zone.local(2026, 10, 15, 23, 50))

      payment = described_class.ensure_for(invoice)

      expect(payment.expires_at).to eq(Time.zone.local(2026, 10, 16, 0, 20))
      expect(stub.with { |request| JSON.parse(request.body).dig("transactions", "payments", 0, "expiration_time") == "PT30M" })
        .to have_been_requested
    end

    it "generates nothing for a paid invoice" do
      invoice.update!(status: "paid", paid_at: Time.current)

      expect(described_class.ensure_for(invoice)).to be_nil
    end

    it "saves nothing when Mercado Pago fails" do
      stub_request(:post, MercadoPagoStub::ORDERS_URL).to_return(status: 500, body: "{}")

      expect { described_class.ensure_for(invoice) }.to raise_error(Billing::MercadoPago::Error)
      expect(Payment.where(invoice: invoice)).to be_empty
    end
  end

  describe ".sync" do
    let!(:payment) do
      stub_create_order
      described_class.ensure_for(invoice)
    end

    def order(**attributes)
      mp_order(id: payment.provider_order_id, external_reference: payment.id, amount_cents: 30_000, **attributes)
    end

    it "pays the invoice, once, however many notices arrive" do
      paid = order(status: "processed", status_detail: "accredited", paid_cents: 30_000)

      2.times { described_class.sync(paid) }

      expect(payment.reload).to have_attributes(status: "approved", paid_at: Time.current, raw_status: "processed/accredited")
      expect(invoice.reload).to have_attributes(status: "paid", paid_at: Time.current)
    end

    it "brings the contract back to active at once, on the 20th day late (CA-19-007, RN-19-053)" do
      subscription.update!(status: "read_only")
      travel_to(Time.zone.local(2026, 11, 4, 15))

      described_class.sync(order(status: "processed", status_detail: "accredited", paid_cents: 30_000))

      expect(subscription.reload).to be_active
    end

    it "keeps the contract while another invoice is still past due" do
      subscription.update!(status: "past_due")
      later = Billing::Invoicing.issue_due(subscription, Date.new(2026, 11, 15), lead: 0).sole
      travel_to(Time.zone.local(2026, 11, 20, 9))

      described_class.sync(order(status: "processed", status_detail: "accredited", paid_cents: 30_000))

      expect(later.reload).to be_open
      expect(subscription.reload).to be_past_due
    end

    it "does not take a payment below the invoice as paid, and reports it" do
      expect(Rails.error).to receive(:report).with(an_instance_of(Billing::MercadoPago::Error), context: { payment_id: payment.id })

      described_class.sync(order(status: "processed", status_detail: "accredited", paid_cents: 10_000))

      expect(payment.reload).to be_pending
      expect(invoice.reload).to be_open
    end

    it "cancels the PIX that expired, and still takes a late payment of it" do
      described_class.sync(order(status: "canceled", status_detail: "expired"))
      expect(payment.reload).to be_cancelled

      described_class.sync(order(status: "processed", status_detail: "accredited", paid_cents: 30_000))
      expect(payment.reload).to be_approved
      expect(invoice.reload).to be_paid
    end

    it "never takes a paid PIX back to cancelled" do
      described_class.sync(order(status: "processed", status_detail: "accredited", paid_cents: 30_000))
      described_class.sync(order(status: "failed", status_detail: "expired"))

      expect(payment.reload).to be_approved
    end

    it "ignores an order that is not ours" do
      expect(described_class.sync(mp_order(id: "ORD999", external_reference: "outro-sistema"))).to be_nil
    end
  end

  describe ".reconcile" do
    let!(:payment) do
      stub_create_order
      described_class.ensure_for(invoice)
    end

    it "finds in the API the PIX paid whose webhook was lost (CA-19-008)" do
      stub_get_order(mp_order(id: payment.provider_order_id, external_reference: payment.id, amount_cents: 30_000, status: "processed",
        status_detail: "accredited", paid_cents: 30_000))

      described_class.reconcile

      expect(invoice.reload).to be_paid
    end

    it "cancels a PIX still pending 31 days after it expired" do
      stub_get_order(mp_order(id: payment.provider_order_id, external_reference: payment.id, amount_cents: 30_000))
      travel_to(Time.zone.local(2026, 11, 16, 2, 30))

      described_class.reconcile

      expect(payment.reload).to be_cancelled
    end

    it "reports a failure and goes on with the other PIX" do
      other_invoice = Billing::Invoicing.issue_due(contract_for(create(:company)), Date.current, lead: 0).sole
      other_invoice.billing_account.update!(billing_email: "rh@outra.example")
      other = described_class.ensure_for(other_invoice)
      stub_request(:get, "#{MercadoPagoStub::ORDERS_URL}/#{payment.provider_order_id}").to_return(status: 503, body: "{}")
      stub_get_order(mp_order(id: other.provider_order_id, external_reference: other.id, amount_cents: 30_000, status: "processed",
        status_detail: "accredited", paid_cents: 30_000))
      expect(Rails.error).to receive(:report).with(an_instance_of(Billing::MercadoPago::Error), context: { payment_id: payment.id })

      described_class.reconcile

      expect(other_invoice.reload).to be_paid
      expect(invoice.reload).to be_open
    end
  end

  it "generates the PIX right after the invoice is issued" do
    stub_create_order

    perform_enqueued_jobs(only: Billing::CreatePixJob) { invoice }

    expect(invoice.payments.sole).to be_pending
  end
end
