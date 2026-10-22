require "rails_helper"

# Spec 19, RN-19-062 (D-489, D-625): the financial responsible cancels the contract on the
# panel, with the password again and a reason, and undoes it until the end of the paid
# cycle; the team undoes it in the admin, with the reason.
RSpec.describe "Contract cancellation", type: :request do
  let(:company) { create(:company, name: "Metalúrgica Serra Azul") }
  let(:brand) { create(:brand, owner: company) }
  let!(:subscription) { contract_for(company) }

  around { |example| travel_to(Time.zone.local(2026, 10, 10, 10)) { example.run } }

  before do
    Flipper.enable(FeatureFlags::SIGN_IN)
    Flipper.enable(FeatureFlags::BILLING)
    publish_platform_legal_documents
    Billing::Invoicing.issue_due(subscription, Date.current, lead: 0).sole.update!(status: "paid", paid_at: Time.current)
    brand.subdomains.create!(slug: "serraazul")
    host! "serraazul.painel.catalysthr.com.br"
  end

  def sign_in_member(roles)
    user = enable_mfa(create(:user, cpf: "98765432100", name: "Helena Prado"))
    create(:membership, user: user, organization: company, roles: roles)
    accept_legal_documents(user, brand)
    sign_in_with_mfa("98765432100", user)
    user
  end

  def confirm_password
    post "/confirm-password", params: { password: "Catalyst#2026", return_to: "/contract/cancellation" }
  end

  it "asks the password, then cancels at the end of the paid cycle, and undoes it (RN-19-062)" do
    sign_in_member(%w[hr_admin])

    get "/invoices"
    expect(response.body).to include("Cancelar contrato")
    get "/contract/cancellation"
    expect(response).to redirect_to(%r{/confirm-password})

    confirm_password
    follow_redirect!
    expect(response.body).to include("O cancelamento vale no fim do ciclo pago, em 09/11/2026", "Vamos usar outro sistema")

    post "/contract/cancellation", params: { reason: "other_system", reason_text: "Vamos centralizar no ERP" }
    expect(response).to redirect_to("/contract/cancellation")
    follow_redirect!
    expect(response.body).to include("O cancelamento está agendado para 09/11/2026", "Helena Prado", "Vamos centralizar no ERP")
    expect(subscription.reload).to be_cancel_scheduled

    get "/invoices"
    expect(response.body).to include("Cancelamento agendado para 09/11/2026")

    delete "/contract/cancellation"
    expect(flash[:notice]).to eq("Cancelamento desfeito. O contrato continua normalmente.")
    expect(subscription.reload).to have_attributes(status: "active", cancel_on: nil)
  end

  it "asks the reason" do
    sign_in_member(%w[hr_admin])
    confirm_password

    post "/contract/cancellation", params: { reason: "other" }

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("Conte o motivo quando escolher")
    expect(subscription.reload).to be_active
  end

  it "keeps the cancellation from the HR analyst" do
    sign_in_member(%w[hr_analyst])

    get "/contract/cancellation"

    expect(response).to have_http_status(:forbidden)
  end

  it "lets the finance team undo it in the admin, with the reason" do
    Billing::Cancellation.schedule(subscription, by: create(:user), reason: "price", text: nil)
    host! "admin.catalysthr.com.br"
    finance = enable_mfa(create(:user, platform_role: "finance", cpf: "52998224725"))
    sign_in_with_mfa("52998224725", finance)

    get "/clients/#{subscription.billing_account.id}"
    expect(response.body).to include("Cancelamento pedido pelo cliente", "Agendado para 09/11/2026", "Preço")

    delete "/clients/#{subscription.billing_account.id}/contract/cancellation", params: { reason: "Desconto negociado" }

    expect(flash[:notice]).to eq("Cancelamento desfeito. O contrato continua normalmente.")
    expect(subscription.reload).to have_attributes(status: "active", cancel_undone_by: finance, cancel_undone_reason: "Desconto negociado")
  end
end
