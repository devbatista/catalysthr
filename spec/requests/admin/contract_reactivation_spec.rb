require "rails_helper"

# Spec 19, RN-19-053 (P-19-18, D-624): only the superadmin reactivates a contract in
# closing, within 90 days, once no invoice is past due, with the reason.
RSpec.describe "Contract reactivation", type: :request do
  let(:partner) { create(:partner, name: "Aurora Gestão de Pessoas") }
  let!(:subscription) { contract_for(partner) }
  let(:account) { subscription.billing_account }

  around { |example| travel_to(Time.zone.local(2026, 11, 10, 9)) { example.run } }

  before do
    Flipper.enable(FeatureFlags::SIGN_IN)
    Flipper.enable(FeatureFlags::BILLING)
    subscription.update!(status: "closing", closing_on: Date.new(2026, 11, 1))
    host! "admin.catalysthr.com.br"
  end

  def sign_in(role)
    user = enable_mfa(create(:user, platform_role: role, cpf: "52998224725"))
    sign_in_with_mfa("52998224725", user)
    user
  end

  it "lets the superadmin reactivate with the reason" do
    superadmin = sign_in("superadmin")

    get "/clients/#{account.id}"
    expect(response.body).to include("Reativar o contrato", "em encerramento desde 01/11/2026", "Até 30/01/2027")

    post "/clients/#{account.id}/contract/reactivation", params: { reason: "Pagou por TED, conferido pelo financeiro" }

    expect(flash[:notice]).to eq("Contrato reativado. A conta e as empresas voltaram ao normal.")
    expect(subscription.reload).to have_attributes(status: "active", reactivated_by: superadmin)
  end

  it "refuses while an invoice is past due" do
    Invoice.create!(billing_account: account, number: 1, period_start: Date.new(2026, 10, 1), period_end: Date.new(2026, 10, 31),
      due_on: Date.new(2026, 10, 1), status: "overdue", total_cents: 1_000, issued_at: Time.current)
    sign_in("superadmin")

    post "/clients/#{account.id}/contract/reactivation", params: { reason: "Promessa de pagamento" }

    expect(flash[:alert]).to eq("Ainda há fatura vencida. Ela precisa ser paga antes de reativar o contrato.")
    expect(subscription.reload).to be_closing
  end

  it "keeps the reactivation from the finance team" do
    sign_in("finance")

    get "/clients/#{account.id}"
    expect(response.body).not_to include("Reativar o contrato")
    post "/clients/#{account.id}/contract/reactivation", params: { reason: "x" }
    expect(response).to have_http_status(:forbidden)
  end
end
