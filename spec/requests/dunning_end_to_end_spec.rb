require "rails_helper"

# Phase 1 "ready when": the dunning schedule end to end with simulated dates (RN-19-040 to
# RN-19-053, CA-19-006, CA-19-007, D-622, D-624). A direct company registered under contract
# by the superadmin goes through the cycles with the daily jobs run in the production order
# (config/schedule.yml), Mercado Pago answered by WebMock: a late invoice paid by PIX in the
# read only, then a cycle never paid, up to the closing and the superadmin's reactivation.
RSpec.describe "Dunning end to end", type: :request do
  include ActiveJob::TestHelper

  DAILY_JOBS = [ Billing::DailyUsageJob, Billing::GenerateInvoicesJob, Billing::ReconcileJob, Billing::CancellationJob,
    Billing::DunningJob ].freeze

  let(:start) { Date.new(2026, 10, 1) }

  before do
    travel_to Time.zone.local(2026, 10, 1, 10)
    Flipper.enable(FeatureFlags::SIGN_IN)
    Flipper.enable(FeatureFlags::BILLING)
    configure_mercado_pago
    publish_platform_legal_documents
    stub_create_order
    # The daily check finds every PIX still waiting (D-622).
    stub_request(:get, %r{\A#{MercadoPagoStub::ORDERS_URL}/}).to_return do |request|
      { status: 200, body: mp_order(id: request.uri.path.split("/").last).to_json, headers: { "Content-Type" => "application/json" } }
    end
    create(:plan_version, plan: create(:plan, :direct, name: "Empresa direta"), price_per_employee_cents: 1_200,
      minimum_monthly_cents: 30_000)
  end

  after { travel_back }

  # A minute later each time: the code from the app is used once (devise-two-factor).
  def sign_in_admin
    travel 1.minute
    reset!
    host! "admin.catalysthr.com.br"
    sign_in_with_mfa("52998224725", superadmin)
  end

  def sign_in_hr
    travel 1.minute
    reset!
    host! "serraazul.painel.catalysthr.com.br"
    sign_in_with_mfa("11144477735", hr_admin)
  end

  let(:superadmin) { enable_mfa(create(:user, platform_role: "superadmin", cpf: "52998224725")) }
  let(:account) { BillingAccount.sole }
  let(:subscription) { account.subscription }
  let(:hr_admin) { account.responsible_user }

  def register_client
    sign_in_admin
    perform_enqueued_jobs(only: Billing::CreatePixJob) do
      post "/clients", params: { client: BillingHelpers::BILLING_ADDRESS.merge(kind: "direct", mode: "contract", legal_name: "Metalúrgica Serra Azul Ltda",
        commercial_name: "Serra Azul", cnpj: "11.222.333/0001-81", slug: "serraazul", plan_id: Plan.sole.id, modules: [],
        admin_name: "Juliana Ribeiro", admin_cpf: "111.444.777-35", admin_email: "juliana@serraazul.example") }
    end
    # The administrator accepts the invitation (spec 02, tested apart).
    Membership.find_by!(user: hr_admin).update!(status: "active")
    hr_admin.update!(password: "Catalyst#2026")
    enable_mfa(hr_admin)
    accept_legal_documents(hr_admin, account.brand)
  end

  # The jobs of a day, at their hours in Brasília, with the PIX of each invoice issued.
  def run_day(date)
    travel_to Time.zone.local(date.year, date.month, date.day, 3)
    perform_enqueued_jobs(only: Billing::CreatePixJob) { DAILY_JOBS.each(&:perform_now) }
    travel_to Time.zone.local(date.year, date.month, date.day, 10)
  end

  def run_days(range) = range.each { |date| run_day(date) }

  def notices(code) = Notification.where(notification_type: code, recipient_user: hr_admin).order(:created_at)

  def can_create_department?
    expect { post "/departments", params: { department: { name: "Produção #{SecureRandom.hex(2)}", unit_id: account.owner.headquarters.id } } }
      .to change { ActsAsTenant.without_tenant { Department.count } }
    true
  rescue RSpec::Expectations::ExpectationNotMetError
    false
  end

  # The responsible opens the invoice (a PIX of the day replaces the expired one, D-622) and
  # pays it; Mercado Pago's signed notice confirms it (RN-19-046).
  def pay(invoice)
    sign_in_hr
    perform_enqueued_jobs(only: Billing::CreatePixJob) { get "/invoices/#{invoice.id}" }
    expect(response.body).to include("Pix copia e cola").or include("copia e cola")
    payment = invoice.payments.pending.order(:created_at).last
    stub_get_order(mp_order(id: payment.provider_order_id, external_reference: payment.id, amount_cents: invoice.total_cents,
      status: "processed", status_detail: "accredited", paid_cents: invoice.total_cents))
    host! "admin.catalysthr.com.br"
    perform_enqueued_jobs(only: Billing::SyncOrderJob) do
      post "/webhooks/mercado-pago?data.id=#{payment.provider_order_id}&type=order",
        params: { action: "order.processed", data: { id: payment.provider_order_id } }.to_json,
        headers: { "Content-Type" => "application/json", "x-signature" => mp_signature(payment.provider_order_id, "req-1"),
          "x-request-id" => "req-1" }
    end
    expect(response).to have_http_status(:ok)
  end

  it "goes from the first invoice to the read only, back to active with the PIX, and to the closing, reactivated by the superadmin" do
    register_client
    first = account.invoices.sole
    expect(first).to have_attributes(status: "open", due_on: start, total_cents: 30_000)
    expect(first.payments.sole).to be_pending

    # Days 1 to 14: past due, with the notices of days 1, 5 and 10 (RN-19-050).
    run_days(start + 1..start + 14)
    expect(first.reload).to be_overdue
    expect(subscription.reload).to be_past_due
    expect(notices("billing.overdue").pluck(:title)).to eq([ "A fatura 000001 de Serra Azul venceu",
      "A fatura 000001 de Serra Azul continua em aberto", "Serra Azul entra em somente leitura em 5 dias" ])
    sign_in_hr
    expect(can_create_department?).to be(true)

    # Day 15: read only; nothing new on the panel, the way to pay stays open (RN-19-051).
    run_day(start + 15)
    expect(subscription.reload).to be_read_only
    sign_in_hr
    get "/"
    expect(response.body).to include("Conta em somente leitura por fatura vencida", "Pagar a fatura")
    expect(can_create_department?).to be(false)

    # Day 17: paid by PIX; active at once, before the next run of the schedule (RN-19-053).
    travel_to Time.zone.local(2026, 10, 18, 10)
    pay(first)
    expect(first.reload).to have_attributes(status: "paid", paid_at: be_present)
    expect(subscription.reload).to be_active
    sign_in_hr
    get "/"
    expect(response.body).not_to include("Conta em somente leitura")
    expect(can_create_department?).to be(true)

    # The next cycle: issued 3 days before, due on day 1 of November, never paid (RN-19-041).
    run_days(start + 18..Date.new(2026, 10, 29))
    second = account.invoices.order(:number).last
    expect(second).to have_attributes(number: 2, status: "open", due_on: Date.new(2026, 11, 1), period_start: Date.new(2026, 11, 1))
    expect(notices("billing.invoice_issued").count).to eq(2)

    # Day 15 of the second invoice: read only again; day 25: the closing notice; day 30:
    # closing (RN-19-050).
    run_days(Date.new(2026, 10, 30)..Date.new(2026, 11, 16))
    expect(subscription.reload).to be_read_only
    run_days(Date.new(2026, 11, 17)..Date.new(2026, 11, 26))
    expect(notices("billing.contract_closing").pluck(:title)).to eq([ "O contrato de Serra Azul entra em encerramento em 5 dias" ])
    run_days(Date.new(2026, 11, 27)..Date.new(2026, 12, 1))
    expect(subscription.reload).to have_attributes(status: "closing", closing_on: Date.new(2026, 12, 1))
    sign_in_hr
    get "/"
    expect(response.body).to include("Contrato em encerramento por falta de pagamento")

    # The superadmin cannot reactivate with an invoice overdue; paying does not reactivate
    # the closing by itself (RN-19-053). December's invoice, issued on November 28 while in
    # read only, must be paid too before the superadmin reactivates, with the reason.
    sign_in_admin
    post "/clients/#{account.id}/contract/reactivation", params: { reason: "Cliente negociou" }
    expect(flash[:alert]).to eq("Ainda há fatura vencida. Ela precisa ser paga antes de reativar o contrato.")
    expect(subscription.reload).to be_closing

    travel_to Time.zone.local(2026, 12, 2, 10)
    pay(second)
    expect(second.reload).to be_paid
    expect(subscription.reload).to be_closing
    run_day(Date.new(2026, 12, 3))
    expect(subscription.reload).to be_closing

    third = account.invoices.find_by!(number: 3)
    expect(third).to have_attributes(due_on: Date.new(2026, 12, 1), status: "open")
    sign_in_admin
    post "/clients/#{account.id}/contract/reactivation", params: { reason: "Cliente pagou a fatura de novembro" }
    expect(flash[:alert]).to eq("Ainda há fatura vencida. Ela precisa ser paga antes de reativar o contrato.")

    pay(third)
    expect(subscription.reload).to be_closing
    sign_in_admin
    post "/clients/#{account.id}/contract/reactivation", params: { reason: "Cliente pagou novembro e dezembro" }
    expect(subscription.reload).to have_attributes(status: "active", reactivated_by: superadmin,
      reactivation_reason: "Cliente pagou novembro e dezembro")
    sign_in_hr
    expect(can_create_department?).to be(true)
  end
end
