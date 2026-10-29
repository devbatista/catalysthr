require "rails_helper"

# Spec 06, block 06a, and spec 11, RN-11-020 (P-11-06, D-336, D-638): the CatalystHR team
# reviews the national holidays and registers the state and city ones, in the admin's
# content (RN-19-080).
RSpec.describe "Admin holidays", type: :request do
  include ActiveJob::TestHelper

  around { |example| travel_to(Time.zone.local(2027, 1, 10, 10)) { example.run } }

  before do
    Flipper.enable(FeatureFlags::SIGN_IN)
    host! "admin.catalysthr.com.br"
  end

  def sign_in(role)
    user = enable_mfa(create(:user, platform_role: role, cpf: "52998224725", name: "Paulo Lima"))
    sign_in_with_mfa("52998224725", user)
    user
  end

  def pending(date, name, unit_opt_out: false)
    Holiday.create!(level: "national", date: Date.parse(date), name: name, status: "pending", source: "brasil_api",
      unit_opt_out: unit_opt_out)
  end

  it "lets the support review the national holidays: publish, with Good Friday, and reject (P-11-06, D-638)" do
    support = sign_in("support")
    good_friday = pending("2027-03-26", "Sexta-feira Santa", unit_opt_out: true)
    carnival = pending("2027-02-08", "Carnaval")

    get "/holidays"
    expect(response.body).to include("Conteúdo", 'href="/holidays"', "2 feriados nacionais aguardando revisão",
      "26/03/2027 (sex)", "Rejeite o Carnaval")

    patch "/holidays/#{good_friday.id}/publish", params: { unit_opt_out: "1" }
    expect(response).to redirect_to("/holidays?year=2027")
    expect(good_friday.reload).to have_attributes(status: "published", unit_opt_out: true, reviewed_by: support)

    patch "/holidays/#{carnival.id}/reject"
    expect(carnival.reload).to have_attributes(status: "rejected", reviewed_by: support)

    get "/holidays"
    expect(response.body).to include("Desmarcável na unidade", "1 feriado rejeitado")
    expect(response.body).not_to include("nacional aguardando revisão", "nacionais aguardando revisão")
  end

  it "registers a city holiday by hand, born published, and edits it (D-336)" do
    superadmin = sign_in("superadmin")

    post "/holidays", params: { holiday: { level: "city", state: "RS", ibge_city_code: "4305108", city_name: "Caxias do Sul",
      date: "2027-06-26", name: "Padroeiro de Caxias" } }

    holiday = Holiday.sole
    expect(response).to redirect_to("/holidays?year=2027")
    expect(holiday).to have_attributes(level: "city", status: "published", source: "manual", reviewed_by: superadmin)

    get "/holidays", params: { state: "RS" }
    expect(response.body).to include("Padroeiro de Caxias", "Caxias do Sul / RS")

    patch "/holidays/#{holiday.id}", params: { holiday: { name: "São Pelegrino", level: "national" } }
    expect(holiday.reload).to have_attributes(name: "São Pelegrino", level: "city")
  end

  it "refuses a city holiday without the IBGE code" do
    sign_in("support")

    post "/holidays", params: { holiday: { level: "city", state: "RS", city_name: "Caxias do Sul", date: "2027-06-26",
      name: "Padroeiro" } }

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("Código IBGE do município")
  end

  it "brings a chosen year from BrasilAPI in the background" do
    sign_in("superadmin")

    post "/holidays/import", params: { year: "2027" }

    expect(response).to redirect_to("/holidays?year=2027")
    expect(Holidays::ImportNationalJob).to have_been_enqueued.with(2027)
  end

  it "deletes a holiday with the units' opt-outs of it" do
    sign_in("superadmin")
    holiday = Holiday.create!(level: "national", date: Date.new(2027, 3, 26), name: "Sexta-feira Santa", unit_opt_out: true)
    company = create(:company)
    ActsAsTenant.with_tenant(company) do
      UnitHoliday.create!(unit: Unit.first, kind: "opt_out", holiday: holiday, created_by: create(:user))
    end

    delete "/holidays/#{holiday.id}"

    expect(Holiday.count).to eq(0)
    expect(ActsAsTenant.with_tenant(company) { UnitHoliday.count }).to eq(0)
  end

  it "keeps the finance team out" do
    sign_in("finance")

    get "/holidays"
    expect(response).to have_http_status(:forbidden)

    get "/"
    expect(response.body).not_to include('href="/holidays"')
  end
end
