require "rails_helper"

# Spec 19, RN-19-070 and RN-19-071 (CA-19-009, D-621): the finance team launches
# adjustments on the client's page; above 20% of the next invoice they wait for the
# superadmin, who approves them on the adjustments screen.
RSpec.describe "Billing adjustments", type: :request do
  include ActiveJob::TestHelper

  let(:partner) { create(:partner, name: "Aurora Gestão de Pessoas") }
  let(:subscription) { contract_for(partner) }
  let(:account) { subscription.billing_account }

  around { |example| travel_to(Time.zone.local(2026, 10, 1, 9)) { example.run } }

  before do
    Flipper.enable(FeatureFlags::SIGN_IN)
    Flipper.enable(FeatureFlags::BILLING)
    Billing::Invoicing.issue_due(subscription, Date.current, lead: 0)
    host! "admin.catalysthr.com.br"
  end

  def sign_in(role, cpf: "52998224725", name: "Paulo Lima")
    user = enable_mfa(create(:user, platform_role: role, cpf: cpf, name: name))
    sign_in_with_mfa(cpf, user)
    user
  end

  def launch(**attributes)
    post "/clients/#{account.id}/adjustments", params: { adjustment: { reason: "Falha nossa no ponto em 03/10", cycles: "1" }.merge(attributes) }
  end

  it "holds a finance team's 25% discount for the superadmin, who approves it (CA-19-009)" do
    superadmin = create(:user, platform_role: "superadmin", name: "Sara Superadmin", cpf: "11144477735")
    sign_in("finance", name: "Fernanda Financeiro")

    get "/clients/#{account.id}/adjustments/new"
    expect(response.body).to include("Lançar ajuste", "passar de 20% da próxima fatura")

    perform_enqueued_jobs { launch(kind: "discount", percent: "25") }

    expect(response).to redirect_to("/clients/#{account.id}")
    expect(flash[:notice]).to include("aguarda a aprovação do superadmin")
    follow_redirect!
    expect(response.body).to include("Desconto de 25%", "Aguardando aprovação", "Falha nossa no ponto")
    expect(response.body).not_to include(">Aprovar<")
    expect(Notification.where(notification_type: "platform.adjustment_pending").sole.recipient_user).to eq(superadmin)

    reset!
    host! "admin.catalysthr.com.br"
    enable_mfa(superadmin)
    sign_in_with_mfa("11144477735", superadmin)
    get "/adjustments"
    expect(response.body).to include("Aguardando aprovação", "Aurora Gestão de Pessoas", "Fernanda Financeiro")

    post "/adjustments/#{BillingAdjustment.sole.id}/approve"

    expect(flash[:notice]).to eq("Ajuste aprovado. Ele vale na próxima fatura emitida.")
    expect(BillingAdjustment.sole).to have_attributes(status: "approved", approved_by: superadmin)
  end

  it "approves at once an adjustment up to 20% and shows what the invoices used" do
    sign_in("finance")

    launch(kind: "credit", value: "300,00")

    expect(flash[:notice]).to eq("Ajuste lançado. Ele vale na próxima fatura emitida.")
    follow_redirect!
    expect(response.body).to include("Crédito de R$ 300,00", "R$ 0,00 de R$ 300,00 usados", "Aprovado")
  end

  it "shows the errors of an adjustment without a reason or amount" do
    sign_in("finance")

    launch(kind: "discount", reason: "")

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("Informe o valor ou o percentual do desconto, não os dois", "Motivo")
    expect(BillingAdjustment.count).to eq(0)
  end

  it "cancels an adjustment not yet in an invoice" do
    sign_in("finance")
    launch(kind: "discount", percent: "25")

    post "/adjustments/#{BillingAdjustment.sole.id}/cancel"

    expect(flash[:notice]).to eq("Ajuste cancelado.")
    expect(BillingAdjustment.sole).to be_cancelled
  end

  it "keeps the approval to the superadmin" do
    sign_in("finance")
    launch(kind: "discount", percent: "25")

    post "/adjustments/#{BillingAdjustment.sole.id}/approve"

    expect(response).to have_http_status(:forbidden)
  end

  it "lets the support read the adjustments but not launch them (spec 19, section 6)" do
    sign_in("support")

    get "/adjustments"
    expect(response).to have_http_status(:ok)
    get "/clients/#{account.id}"
    expect(response.body).not_to include("Lançar ajuste")
    launch(kind: "discount", percent: "5")
    expect(response).to have_http_status(:forbidden)
  end

  it "hides the adjustments while billing is off (D-610)" do
    sign_in("finance")
    Flipper.disable(FeatureFlags::BILLING)

    get "/adjustments"
    expect(response).to have_http_status(:not_found)
  end
end
