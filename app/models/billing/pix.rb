module Billing
  # The PIX of each invoice (RN-19-042, RN-19-046, RN-19-053, CA-19-007, CA-19-008, D-622):
  # generated in Mercado Pago's Orders API when the invoice is issued, valid until the end of
  # its due date; once it expires, a new one is generated when the payer opens the invoice,
  # valid until the end of that day. Mercado Pago tells the payment by the webhook, and the
  # daily check reads the pending ones; either way, `sync` applies the order's status.
  module Pix
    # Mercado Pago's shortest PIX (30 minutes to 30 days).
    MIN_DURATION = 30.minutes
    # How long a pending PIX is still read after it expires: Mercado Pago considers it
    # expired 30 days after its due date.
    CHECK_AFTER_EXPIRY = 31.days
    REACTIVATED = %w[past_due read_only].freeze

    module_function

    # The invoice's PIX still valid, generating a new one when there is none. Nothing for an
    # invoice paid, void or with nothing to charge. Raises MercadoPago::Error when Mercado
    # Pago fails; nothing is saved then.
    def ensure_for(invoice, now: Time.current)
      return unless invoice.payable?

      invoice.with_lock do
        next unless invoice.payable?

        last = invoice.payments.pix.pending.order(:created_at).last
        last&.live?(now) ? last : create(invoice, now)
      end
    end

    def create(invoice, now)
      expires_at = now + duration(invoice, now)
      payment = invoice.payments.create!(payment_method: "pix", status: "pending", amount_cents: invoice.total_cents,
        idempotency_key: SecureRandom.uuid, expires_at: expires_at)
      order = MercadoPago.create_order(order_body(invoice, payment, expires_at - now), idempotency_key: payment.idempotency_key)
      transaction = order.dig("transactions", "payments", 0) || {}
      method = transaction["payment_method"] || {}
      payment.update!(provider_order_id: order["id"], provider_payment_id: transaction["id"], raw_status: raw_status(order),
        qr_code: method["qr_code"], qr_code_base64: method["qr_code_base64"], ticket_url: method["ticket_url"])
      payment
    end

    # Until the end of the due date, or of today once it has passed; never under 30 minutes.
    def duration(invoice, now)
      due_end = invoice.due_on.in_time_zone.end_of_day
      target = due_end > now ? due_end : now.end_of_day
      [ (target - now).floor, MIN_DURATION.to_i ].max.seconds
    end

    def order_body(invoice, payment, duration)
      amount = MoneyCents.decimal(payment.amount_cents)
      {
        type: "online",
        processing_mode: "automatic",
        total_amount: amount,
        external_reference: payment.id,
        payer: { email: payer_email(invoice.billing_account) },
        transactions: { payments: [ { amount: amount, payment_method: { id: "pix", type: "bank_transfer" },
          expiration_time: ActiveSupport::Duration.build(duration.to_i).iso8601 } ] }
      }
    end

    # The billing e-mail (RN-19-044), or the responsible's.
    def payer_email(account)
      account.billing_email || account.responsible_user&.email || account.notice_recipients.first&.user&.email
    end

    def raw_status(order)
      [ order["status"], order["status_detail"] ].compact.join("/")
    end

    # Applies a Mercado Pago order to its payment (RN-19-046). Repeated or out-of-order
    # notices change nothing: a paid PIX never goes back. Returns the payment, or nil for an
    # order that is not ours.
    def sync(order, now: Time.current)
      payment = Payment.find_by(provider_order_id: order["id"]) if order["id"].present?
      payment ||= Payment.find_by(id: order["external_reference"]) if order["external_reference"].to_s.match?(/\A\h{8}-\h{4}-\h{4}-\h{4}-\h{12}\z/)
      return unless payment

      payment.invoice.with_lock do
        payment.reload
        payment.assign_attributes(provider_order_id: payment.provider_order_id || order["id"], raw_status: raw_status(order))
        case order["status"]
        when "processed" then approve(payment, order, now)
        when "canceled", "failed" then payment.status = "cancelled" if payment.pending?
        when "refunded" then payment.status = "refunded" if payment.approved?
        end
        payment.save!
      end
      payment
    end

    # Paid: the PIX, the invoice, and the contract back to `active` right away (RN-19-053,
    # CA-19-007), unless another invoice is still past due. A payment below the amount is
    # not taken as paid and is reported.
    def approve(payment, order, now)
      return if payment.approved? || payment.refunded?

      paid = MoneyCents.parse(order["total_paid_amount"].presence || order["total_amount"])
      unless paid.is_a?(Integer) && paid >= payment.amount_cents
        Rails.error.report(MercadoPago::Error.new("PIX paid below the invoice"), context: { payment_id: payment.id })
        return
      end

      payment.assign_attributes(status: "approved", paid_at: now)
      invoice = payment.invoice
      invoice.update!(status: "paid", paid_at: now) if invoice.payable?
      reactivate(invoice.billing_account, now.to_date)
    end

    def reactivate(account, today)
      subscription = account.subscription
      return unless subscription&.status.in?(REACTIVATED)
      return if account.invoices.any? { |invoice| invoice.past_due?(today) }

      subscription.update!(status: "active")
    end

    # The daily check (RN-19-046, CA-19-008): every pending PIX is read in the API, in case
    # its webhook was lost; one still pending 31 days after it expired is cancelled. A
    # payment is only saved with its order, so every pending one has it. A failure of one
    # does not stop the others; it is reported and read again the next day.
    def reconcile(now: Time.current)
      Payment.pix.pending.where.not(provider_order_id: nil).find_each do |payment|
        sync(MercadoPago.order(payment.provider_order_id), now: now)
        payment.reload
        payment.update!(status: "cancelled") if payment.pending? && payment.expires_at + CHECK_AFTER_EXPIRY < now
      rescue MercadoPago::Error => e
        Rails.error.report(e, context: { payment_id: payment.id })
      end
    end
  end
end
