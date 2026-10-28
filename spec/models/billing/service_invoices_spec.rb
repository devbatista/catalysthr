require "rails_helper"

# Spec 19, section 4.11 (RN-19-103 to RN-19-105, RN-19-108, RN-19-109, CA-19-015, D-633):
# the paid invoice's NFS-e, sent to Asaas with the contract as the customer, scheduled for
# the cycle's first day or today, and every call safe to repeat.
RSpec.describe Billing::ServiceInvoices do
  include ActiveJob::TestHelper

  let(:partner) { create(:partner, name: "Aurora Gestão de Pessoas", legal_name: "Aurora Gestão de Pessoas Ltda") }
  let(:subscription) { contract_for(partner) }
  let(:account) { subscription.billing_account }
  let(:finance) { create(:user, platform_role: "finance", cpf: "52998224725") }
  let(:invoice) { account.invoices.sole }

  around { |example| travel_to(Time.zone.local(2026, 10, 29, 10)) { example.run } }

  before do
    Flipper.enable(FeatureFlags::NFSE)
    configure_asaas
    FiscalSetting.current.tap { |setting| setting.assign_attributes(service_code: "010501", updated_by: finance) }.save!
    Billing::Invoicing.issue_due(subscription, Date.current, lead: 0)
    # A cycle from 01/11 to 30/11, paid before it starts.
    invoice.update_columns(period_start: Date.new(2026, 11, 1), period_end: Date.new(2026, 11, 30))
  end

  def pay(invoice = self.invoice)
    invoice.update!(status: "paid", paid_at: Time.current)
    invoice.service_invoice
  end

  def stub_customer_lookup(found: [])
    stub_asaas(:get, "/customers?externalReference=#{account.id}", body: { data: found })
  end

  def stub_note_lookup(note, found: [])
    stub_asaas(:get, "/invoices?externalReference=#{note.id}", body: { data: found })
  end

  def stub_create_customer
    stub_asaas(:post, "/customers", body: { id: "cus_000001" })
  end

  def stub_schedule(effective_date: "2026-11-01")
    stub_asaas(:post, "/invoices", body: { id: "inv_000001", status: "SCHEDULED", effectiveDate: effective_date })
  end

  describe ".request" do
    it "creates the pending note and its job once the invoice is paid (RN-19-104)" do
      note = nil
      expect { note = pay }.to have_enqueued_job(Billing::IssueServiceInvoiceJob)

      expect(note).to have_attributes(status: "pending", amount_cents: invoice.total_cents, competence_on: Date.new(2026, 11, 1))
      expect { described_class.request(invoice) }.not_to change(ServiceInvoice, :count)
    end

    it "issues nothing while the notes are off (D-633)" do
      Flipper.disable(FeatureFlags::NFSE)

      expect(pay).to be_nil
    end

    it "issues nothing for an invoice of value zero (RN-19-105, CA-19-015)" do
      invoice.update_columns(total_cents: 0)

      expect(pay).to be_nil
    end
  end

  describe ".issue" do
    let(:note) { perform_enqueued_jobs(only: []) { pay } }

    it "registers the partner as a customer, without e-mail, and schedules the note for the cycle's first day" do
      stub_customer_lookup
      customer = stub_create_customer
      stub_note_lookup(note)
      schedule = stub_schedule

      described_class.issue(note)

      expect(customer.with { |request|
        body = JSON.parse(request.body)
        body == { "name" => "Aurora Gestão de Pessoas Ltda", "cpfCnpj" => partner.cnpj, "externalReference" => account.id,
          "notificationDisabled" => true }
      }).to have_been_requested
      expect(schedule.with { |request|
        body = JSON.parse(request.body)
        body.slice("customer", "externalReference", "value", "deductions", "effectiveDate", "municipalServiceCode") ==
          { "customer" => "cus_000001", "externalReference" => note.id, "value" => invoice.total_cents / 100.0, "deductions" => 0,
            "effectiveDate" => "2026-11-01", "municipalServiceCode" => "010501" } &&
          body["taxes"].slice("iss", "retainIss", "nbsCode", "operationIndicatorCode") ==
            { "iss" => 0, "retainIss" => false, "nbsCode" => "1.1506.21.00", "operationIndicatorCode" => "100501" } &&
          body["serviceDescription"].start_with?("Licenciamento de software CatalystHR por assinatura - Competência 11/2026. " \
            "Período de 01/11/2026 a 30/11/2026.")
      }).to have_been_requested
      expect(note.reload).to have_attributes(status: "scheduled", asaas_invoice_id: "inv_000001", effective_on: Date.new(2026, 11, 1))
      expect(account.reload.asaas_customer_id).to eq("cus_000001")
    end

    it "schedules for today when the payment comes after the cycle started (D-633)" do
      note
      travel 22.days
      account.update!(asaas_customer_id: "cus_000001")
      stub_asaas(:put, "/customers/cus_000001", body: { id: "cus_000001" })
      stub_note_lookup(note)
      schedule = stub_schedule(effective_date: "2026-11-20")

      described_class.issue(note)

      expect(schedule.with { |request| JSON.parse(request.body)["effectiveDate"] == "2026-11-20" }).to have_been_requested
      expect(note.reload.competence_on).to eq(Date.new(2026, 11, 1))
    end

    it "updates the customer it already has, so a change reaches Asaas before the note (RN-19-103)" do
      account.update!(asaas_customer_id: "cus_000001")
      update = stub_asaas(:put, "/customers/cus_000001", body: { id: "cus_000001" })
      stub_note_lookup(note)
      stub_schedule

      described_class.issue(note)

      expect(update).to have_been_requested
      expect(a_request(:post, "#{AsaasStub::BASE_URL}/customers")).not_to have_been_made
    end

    it "takes the customer and the note Asaas already has with our reference, without creating them again" do
      stub_customer_lookup(found: [ { id: "cus_000009", externalReference: account.id } ])
      stub_note_lookup(note, found: [ { id: "inv_000001", status: "ERROR", externalReference: note.id },
        { id: "inv_000002", status: "SCHEDULED", externalReference: note.id, effectiveDate: "2026-11-01" } ])

      described_class.issue(note)

      expect(a_request(:post, "#{AsaasStub::BASE_URL}/customers")).not_to have_been_made
      expect(a_request(:post, "#{AsaasStub::BASE_URL}/invoices")).not_to have_been_made
      expect(note.reload).to have_attributes(status: "scheduled", asaas_invoice_id: "inv_000002")
      expect(account.reload.asaas_customer_id).to eq("cus_000009")
    end

    it "registers a direct company by the headquarters' CNPJ and address" do
      company = Company.create_with_cnpj!(cnpj: "11222333000181", name: "Serra Azul", legal_name: "Metalúrgica Serra Azul Ltda")
      ActsAsTenant.with_tenant(company) do
        company.headquarters.update!(postal_code: "04696-180", street: "Rua Padre Fernando Pedreira de Castro", street_number: "30",
          district: "Jurubatuba", city: "São Paulo", state: "SP")
      end
      direct = contract_for(company).billing_account

      expect(described_class.customer_body(direct)).to eq(name: "Metalúrgica Serra Azul Ltda", cpfCnpj: "11222333000181",
        externalReference: direct.id, notificationDisabled: true, postalCode: "04696180",
        address: "Rua Padre Fernando Pedreira de Castro", addressNumber: "30", province: "Jurubatuba")
    end

    it "shows Asaas's refusal on the note and tells the finance team and the superadmins (RN-19-108)" do
      superadmin = create(:user, platform_role: "superadmin", cpf: "11144477735")
      support = create(:user, platform_role: "support", cpf: "39053344705")
      stub_customer_lookup
      stub_create_customer
      stub_note_lookup(note)
      stub_asaas(:post, "/invoices", status: 400, body: { errors: [ { code: "invalid_object", description: "Código NBS inválido." } ] })

      described_class.issue(note)

      expect(note.reload).to have_attributes(status: "error", error_message: "Código NBS inválido.", errors_count: 1)
      recipients = Notification.where(notification_type: "platform.nfse_error").map(&:recipient_user)
      expect(recipients).to include(finance, superadmin)
      expect(recipients).not_to include(support)
      expect(recipients.map(&:platform_role)).to all(be_in(%w[superadmin finance]))
    end

    it "refuses to send without the fiscal settings" do
      FiscalSetting.delete_all

      described_class.issue(note)

      expect(note.reload).to have_attributes(status: "error", error_message: /configuração fiscal não foi preenchida/)
    end

    it "raises a transient failure, for the job to try again (RN-19-109)" do
      stub_request(:get, "#{AsaasStub::BASE_URL}/customers?externalReference=#{account.id}").to_return(status: 503)

      expect { described_class.issue(note) }.to raise_error(Billing::Asaas::Error) { |error| expect(error).to be_transient }
      expect(note.reload).to be_pending
    end
  end

  describe ".reissue" do
    it "sends again only a note with an error, as it is now (RN-19-108)" do
      note = perform_enqueued_jobs(only: []) { pay }
      expect(described_class.reissue(note)).to be(false)

      note.update!(status: "error", error_message: "Código NBS inválido.", asaas_invoice_id: "inv_000001")

      expect { expect(described_class.reissue(note)).to be(true) }.to have_enqueued_job(Billing::IssueServiceInvoiceJob)
      expect(note.reload).to have_attributes(status: "pending", error_message: nil, asaas_invoice_id: nil)
    end
  end
end
