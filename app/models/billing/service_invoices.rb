module Billing
  # The NFS-e of each paid invoice, through Asaas (spec 19, section 4.11, D-560 to D-565,
  # D-628, D-632, D-633). The payment confirmed, the note is born `pending` and a job sends
  # it: the contract as Asaas's customer, created or updated first (RN-19-103), then the
  # note, scheduled for the cycle's first day or today, whichever comes later, so that its
  # competence is the cycle's month (D-628, D-633). Asaas out of the air is tried again
  # (RN-19-109); a refusal shows on the invoice and goes to the finance team and the
  # superadmins, who issue it again after fixing it (RN-19-108). Every call is safe to
  # repeat: the customer and the note carry our reference and are looked up before being
  # created, since Asaas accepts duplicates.
  module ServiceInvoices
    TIME_ZONE = "America/Sao_Paulo".freeze

    module_function

    # Called when an invoice is paid (RN-19-104). Nothing for an invoice without a value
    # (RN-19-105, CA-19-015), while the notes are off (D-633) or when it already has one.
    def request(invoice)
      return unless FeatureFlags.enabled?(FeatureFlags::NFSE) && invoice.paid? && invoice.total_cents.positive?

      note = ServiceInvoice.create_or_find_by!(invoice: invoice) do |record|
        record.assign_attributes(status: "pending", amount_cents: invoice.total_cents, competence_on: invoice.period_start.beginning_of_month)
      end
      IssueServiceInvoiceJob.perform_later(note) if note.pending?
      note
    end

    # Sends a pending note to Asaas. A transient failure raises, for the job to try again.
    def issue(note, today: Time.current.in_time_zone(TIME_ZONE).to_date)
      return unless note.pending?

      setting = FiscalSetting.first
      return fail!(note, I18n.t("billing.service_invoices.errors.no_setting")) unless setting
      return fail!(note, I18n.t("billing.service_invoices.errors.no_asaas")) unless Asaas.configured?

      invoice = note.invoice
      customer_id = ensure_customer(invoice.billing_account)
      return fail!(note, I18n.t("billing.service_invoices.errors.no_document")) unless customer_id

      body = invoice_body(note, setting, customer_id, today)
      answer = Asaas.find_invoice(note.id) || Asaas.schedule_invoice(body)
      note.update!(status: "scheduled", asaas_invoice_id: answer["id"], effective_on: answer["effectiveDate"] || body[:effectiveDate],
        service_description: body[:serviceDescription], service_code: body[:municipalServiceCode], error_message: nil)
    rescue Asaas::Error => e
      raise if e.transient?

      fail!(note, e.description.presence || I18n.t("billing.service_invoices.errors.refused"))
    end

    # The contract as Asaas's customer (RN-19-103, D-633): updated before every note, so a
    # change reaches Asaas before the next one; without e-mail and with Asaas's notices
    # off, so Asaas never writes to the client (D-564). Nil without the document.
    def ensure_customer(account)
      body = customer_body(account)
      return unless body

      if account.asaas_customer_id
        Asaas.update_customer(account.asaas_customer_id, body)
      else
        customer = Asaas.find_customer(account.id) || Asaas.create_customer(body)
        account.update!(asaas_customer_id: customer["id"])
      end
      account.asaas_customer_id
    end

    def customer_body(account)
      owner = account.owner
      document = account.partner? ? owner.cnpj : company_document(owner)
      return if document.blank?

      body = { name: owner.legal_name, cpfCnpj: document, externalReference: account.id, notificationDisabled: true }
      account.partner? ? body : body.merge(company_address(owner))
    end

    # A person employer goes by the CPF; a company by the headquarters' full CNPJ.
    def company_document(company)
      return company.document if company.person?

      headquarters = company.headquarters
      headquarters.registration_number if headquarters&.cnpj?
    end

    def company_address(company)
      headquarters = company.headquarters
      return {} unless headquarters

      { postalCode: headquarters.postal_code, address: headquarters.street, addressNumber: headquarters.street_number,
        complement: headquarters.complement, province: headquarters.district }.compact_blank
    end

    # The note (RN-19-105, D-632, D-633): the amount paid, the codes of the fiscal settings
    # and no Simples rate (D-628).
    def invoice_body(note, setting, customer_id, today)
      invoice = note.invoice
      {
        customer: customer_id,
        externalReference: note.id,
        serviceDescription: description(invoice, setting),
        observations: setting.observations,
        value: note.amount_cents / 100.0,
        deductions: 0,
        effectiveDate: [ today, invoice.period_start ].max.iso8601,
        municipalServiceCode: setting.service_code,
        municipalServiceName: setting.service_name,
        taxes: {
          retainIss: setting.retain_iss,
          iss: 0,
          pis: setting.pis_rate.to_f,
          cofins: setting.cofins_rate.to_f,
          csll: setting.csll_rate.to_f,
          inss: setting.inss_rate.to_f,
          ir: setting.ir_rate.to_f,
          nbsCode: setting.nbs_code,
          operationIndicatorCode: setting.operation_indicator_code
        }
      }
    end

    # "Licenciamento ... - Competência 11/2026. Período de 01/11/2026 a 30/11/2026. Plano
    # Essencial: R$ 300,00; Excedente de colaboradores (10/2026): R$ 24,00." The lines carry
    # their own measurement period (D-628).
    def description(invoice, setting)
      lines = invoice.lines.map { |line| "#{line.description}: R$ #{MoneyCents.format(line.total_cents)}" }
      I18n.t("billing.service_invoices.description", text: setting.description, competence: I18n.l(invoice.period_start, format: "%m/%Y"),
        from: I18n.l(invoice.period_start), to: I18n.l(invoice.period_end), lines: lines.join("; "))
    end

    # A refusal or the tries spent (RN-19-108, RN-19-109): on the invoice, and to the
    # finance team and the superadmins, once per failure.
    def fail!(note, message)
      note.update!(status: "error", error_message: message, errors_count: note.errors_count + 1)
      account = note.invoice.billing_account
      User.active.where(platform_role: %w[superadmin finance]).find_each do |user|
        Notifications.notify!("platform.nfse_error", user: user, area: "admin", subject: note, path: "/invoices/#{note.invoice_id}",
          dedup_key: "platform.nfse_error/#{note.id}/#{note.errors_count}", name: account.name, number: note.invoice.display_number)
      end
      note
    end

    # "Emitir de novo" (RN-19-108): a note with an error goes back to pending and is sent
    # again, with the fiscal settings and the client's data as they are now.
    def reissue(note)
      return false unless note.error?

      note.update!(status: "pending", error_message: nil, asaas_invoice_id: nil)
      IssueServiceInvoiceJob.perform_later(note)
      true
    end
  end
end
