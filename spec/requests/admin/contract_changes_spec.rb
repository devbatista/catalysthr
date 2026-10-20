require "rails_helper"

# Spec 19, RN-19-014, RN-19-015, RN-19-060 and RN-19-061 (CA-19-005, D-620): the finance
# team and the superadmin change a contract on the client's page and create private plans.
RSpec.describe "Contract changes", type: :request do
  include ActiveJob::TestHelper

  let(:partner) { create(:partner, name: "Aurora Gestão de Pessoas") }
  let(:subscription) { contract_for(partner, modules: %w[folha]) }
  let(:account) { subscription.billing_account }

  around { |example| travel_to(Time.zone.local(2026, 10, 1, 9)) { example.run } }

  before do
    Flipper.enable(FeatureFlags::SIGN_IN)
    Flipper.enable(FeatureFlags::BILLING)
    host! "admin.catalysthr.com.br"
    Billing::Invoicing.issue_due(subscription, Date.current, lead: 0)
  end

  def sign_in(role)
    user = enable_mfa(create(:user, platform_role: role, cpf: "52998224725", name: "Paulo Lima"))
    sign_in_with_mfa("52998224725", user)
    user
  end

  it "contracts a module in the middle of the cycle, with the proration on the next invoice (CA-19-005)" do
    travel_to(Time.zone.local(2026, 10, 10, 9))
    finance = sign_in("finance")

    get "/clients/#{account.id}"
    expect(response.body).to include("Alterar o contrato", "Não contratado", "Contratado")

    post "/clients/#{account.id}/contract/modules/ponto"

    expect(response).to redirect_to("/clients/#{account.id}")
    expect(flash[:notice]).to eq("Módulo Ponto contratado a partir de hoje. O proporcional de R$ 283,87 entra na próxima fatura.")
    expect(account.prorations.sole).to have_attributes(total_cents: 28_387, created_by: finance)
    expect(subscription.reload.modules).to contain_exactly("folha", "ponto")
  end

  it "removes a module after the last day invoiced, warning that the data stay, and keeps it again" do
    sign_in("finance")

    get "/clients/#{account.id}"
    expect(response.body).to include("Os dados continuam guardados e em leitura")

    delete "/clients/#{account.id}/contract/modules/folha"
    expect(flash[:notice]).to eq("O módulo Folha sai em 01/11/2026. Os dados continuam guardados e em leitura.")
    follow_redirect!
    expect(response.body).to include("Sai em 31/10/2026", "Manter")

    post "/clients/#{account.id}/contract/modules/folha"
    expect(subscription.reload.items.sole.ends_on).to be_nil
  end

  it "changes the plan at once when the month costs more, and schedules it otherwise" do
    sign_in("finance")
    bigger = create(:plan_version, plan: create(:plan, name: "Até 1.000 colaboradores"), monthly_price_cents: 200_000).plan
    smaller = create(:plan_version, plan: create(:plan, name: "Até 200 colaboradores"), monthly_price_cents: 100_000).plan

    patch "/clients/#{account.id}/contract/plan", params: { plan_id: bigger.id }
    expect(flash[:notice]).to eq("Plano trocado para Até 1.000 colaboradores a partir de hoje. O proporcional de R$ 500,00 entra na próxima fatura.")

    patch "/clients/#{account.id}/contract/plan", params: { plan_id: smaller.id }
    expect(flash[:notice]).to eq("Troca para o plano Até 200 colaboradores agendada para 01/11/2026, no próximo ciclo.")
    follow_redirect!
    expect(response.body).to include("Redução agendada: plano Até 200 colaboradores")

    delete "/clients/#{account.id}/contract/plan"
    expect(subscription.reload).to have_attributes(plan_version: bigger.version_on, next_plan_version: nil)
  end

  it "migrates the contract to the plan's newer price with 30 days' notice (RN-19-014)" do
    sign_in("finance")
    newer = create(:plan_version, plan: subscription.plan, monthly_price_cents: 180_000)

    get "/clients/#{account.id}"
    expect(response.body).to include("versão de preço mais nova (versão 2", "atual · R$ 1.500,00 por mês")

    patch "/clients/#{account.id}/contract/plan", params: { plan_id: subscription.plan.id }
    expect(flash[:alert]).to include("use a migração de preço, com aviso de 30 dias")
    expect(subscription.reload.plan_version.version).to eq(1)

    perform_enqueued_jobs { post "/clients/#{account.id}/contract/price-migration" }

    expect(flash[:notice]).to eq("Migração agendada para 01/11/2026. O responsável recebeu o aviso.")
    expect(subscription.reload.next_plan_version).to eq(newer)
    follow_redirect!
    expect(response.body).to include("Migração de preço agendada")
    expect(response.body).not_to include("Migrar para o preço novo")
  end

  it "creates a private plan offered only to its client (RN-19-015)" do
    sign_in("finance")
    other = contract_for(create(:partner, name: "Outro Parceiro")).billing_account

    post "/plans", params: {
      plan: { kind: "partner", name: "Aurora negociado", private: "1", billing_account_id: account.id },
      plan_version: { monthly_price: "1.200,00", employee_limit: "500", overage_per_employee: "3,00", ai_credits: "1000",
                      whatsapp_messages: "2000", ai_credit_overage: "0,50", whatsapp_overage: "0,35",
                      module_prices: { ponto: "400,00", folha: "600,00" }, valid_from: Date.current.iso8601 }
    }

    plan = Plan.find_by!(name: "Aurora negociado")
    expect(plan).to have_attributes(private: true, billing_account: account)
    get "/plans"
    expect(response.body).to include("Privado de Aurora Gestão de Pessoas")
    get "/clients/#{account.id}"
    expect(response.body).to include("Aurora negociado · privado")
    get "/clients/#{other.id}"
    expect(response.body).not_to include("Aurora negociado")
    get "/clients/new", params: { kind: "partner" }
    expect(response.body).not_to include("Aurora negociado")

    patch "/clients/#{other.id}/contract/plan", params: { plan_id: plan.id }
    expect(flash[:alert]).to eq("Escolha outro plano, ativo e com preço vigente.")
  end

  it "refuses a private plan without its client" do
    sign_in("finance")

    post "/plans", params: { plan: { kind: "partner", name: "Sem cliente", private: "1" },
      plan_version: { monthly_price: "1.200,00", employee_limit: "500", overage_per_employee: "3,00", ai_credits: "1000",
                      whatsapp_messages: "2000", ai_credit_overage: "0,50", whatsapp_overage: "0,35",
                      module_prices: { ponto: "400,00", folha: "600,00" }, valid_from: Date.current.iso8601 } }

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("precisa ser escolhido num plano privado")
  end

  it "lets the support read the contract but not change it (spec 19, section 6)" do
    sign_in("support")

    get "/clients/#{account.id}"
    expect(response.body).not_to include("Alterar o contrato")
    post "/clients/#{account.id}/contract/modules/ponto"
    expect(response).to have_http_status(:forbidden)
  end

  it "changes nothing in a contract in closing" do
    sign_in("finance")
    subscription.update!(status: "closing")

    post "/clients/#{account.id}/contract/modules/ponto"

    expect(flash[:alert]).to eq("Um contrato em encerramento ou encerrado não muda.")
    expect(subscription.reload.modules).to eq(%w[folha])
  end
end
