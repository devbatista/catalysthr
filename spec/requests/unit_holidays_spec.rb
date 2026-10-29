require "rails_helper"

# Spec 06, block 06a (RN-06-029, D-242, D-638): the unit's holidays on its page. The HR
# administrator adds holidays and optional days and turns off Good Friday; the HR analyst
# only reads.
RSpec.describe "Unit holidays", type: :request do
  let(:company) { create(:company, name: "Metalúrgica Serra Azul", document: "11222333") }
  let(:brand) { create(:brand, owner: company, commercial_name: "Serra Azul RH") }
  let!(:hr_admin) { enable_mfa(create(:user, name: "Carlos Mendes", cpf: "98765432100")) }
  let(:branch) do
    ActsAsTenant.with_tenant(company) { Unit.create!(name: "Filial Caxias", state: "RS", city: "Caxias do Sul", ibge_city_code: "4305108") }
  end
  let!(:good_friday) { Holiday.create!(level: "national", date: Date.new(2027, 3, 26), name: "Sexta-feira Santa", unit_opt_out: true) }

  around { |example| travel_to(Time.zone.local(2027, 1, 10, 10)) { example.run } }

  before do
    create(:membership, user: hr_admin, organization: company, roles: %w[hr_admin])
    brand.subdomains.create!(slug: "serraazul")
    Flipper.enable(FeatureFlags::SIGN_IN)
    publish_platform_legal_documents
    accept_legal_documents(hr_admin, brand)
    host! "serraazul.painel.catalysthr.com.br"
    Holiday.create!(level: "national", date: Date.new(2027, 11, 15), name: "Proclamação da República")
    Holiday.create!(level: "national", date: Date.new(2027, 2, 8), name: "Carnaval", status: "rejected")
    Holiday.create!(level: "state", state: "RS", date: Date.new(2027, 9, 20), name: "Revolução Farroupilha")
    Holiday.create!(level: "state", state: "SC", date: Date.new(2027, 8, 11), name: "Data de SC")
    Holiday.create!(level: "city", state: "RS", ibge_city_code: "4305108", city_name: "Caxias do Sul", date: Date.new(2027, 6, 26),
      name: "Padroeiro de Caxias")
  end

  def own_days
    ActsAsTenant.with_tenant(company) { UnitHoliday.where(unit: branch).order(:date).to_a }
  end

  describe "for the HR administrator" do
    before { sign_in_with_mfa("98765432100", hr_admin) }

    it "shows the year's holidays that reach the unit" do
      get "/units/#{branch.id}"

      expect(response.body).to include("Feriados de 2027", "Sexta-feira Santa", "Revolução Farroupilha", "Padroeiro de Caxias",
        "Caxias do Sul / RS", "Estadual (RS)", "Não é feriado aqui", "Incluir feriado ou ponto facultativo")
      expect(response.body).not_to include("Carnaval", "Data de SC")
    end

    it "adds a holiday and an optional day, and deletes one" do
      post "/units/#{branch.id}/holidays", params: { year: "2027", unit_holiday: { date: "2027-07-01", name: "Festa da fábrica", kind: "holiday" } }
      expect(response).to redirect_to("/units/#{branch.id}?year=2027#holidays")
      post "/units/#{branch.id}/holidays", params: { year: "2027", unit_holiday: { date: "2027-07-02", name: "Véspera", kind: "optional_day" } }

      expect(own_days.map { |day| [ day.kind, day.name, day.created_by ] }).to eq([
        [ "holiday", "Festa da fábrica", hr_admin ], [ "optional_day", "Véspera", hr_admin ]
      ])

      delete "/units/#{branch.id}/holidays/#{own_days.first.id}"
      expect(own_days.map(&:name)).to eq([ "Véspera" ])
    end

    it "turns off Good Friday in the unit and turns it on again (D-638)" do
      post "/units/#{branch.id}/holidays", params: { year: "2027", holiday_id: good_friday.id }

      expect(own_days.sole).to have_attributes(kind: "opt_out", holiday: good_friday, date: Date.new(2027, 3, 26))
      get "/units/#{branch.id}"
      expect(response.body).to include("Não é feriado nesta unidade", "Voltar a considerar")

      delete "/units/#{branch.id}/holidays/#{own_days.sole.id}"
      expect(own_days).to be_empty
    end

    it "refuses turning off a holiday the team does not allow" do
      national = Holiday.find_by!(name: "Proclamação da República")

      post "/units/#{branch.id}/holidays", params: { year: "2027", holiday_id: national.id }

      expect(response).to redirect_to("/units/#{branch.id}?year=2027#holidays")
      expect(flash[:alert]).to include("não pode ser desmarcado na unidade")
      expect(own_days).to be_empty
    end

    it "warns when the unit has no IBGE code, so the city holidays do not reach it" do
      branch.update!(ibge_city_code: nil)

      get "/units/#{branch.id}"
      expect(response.body).to include("não tem o código IBGE do município")
      expect(response.body).not_to include("Padroeiro de Caxias")
    end

    it "answers 404 for another company's unit (RN-01-013)" do
      other = create(:company)
      foreign = ActsAsTenant.with_tenant(other) { Unit.create!(name: "Filial de outra") }

      post "/units/#{foreign.id}/holidays", params: { unit_holiday: { date: "2027-07-01", name: "Festa", kind: "holiday" } }
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "for the HR analyst" do
    let!(:analyst) { enable_mfa(create(:user, cpf: "11144477735")) }

    before do
      create(:membership, user: analyst, organization: company, roles: %w[hr_analyst])
      accept_legal_documents(analyst, brand)
      sign_in_with_mfa("11144477735", analyst)
    end

    it "reads the unit's holidays but changes nothing (spec 03, section 4.2)" do
      day = ActsAsTenant.with_tenant(company) do
        UnitHoliday.create!(unit: branch, kind: "holiday", date: Date.new(2027, 7, 1), name: "Festa da fábrica", created_by: hr_admin)
      end

      get "/units/#{branch.id}"
      expect(response.body).to include("Festa da fábrica", "Sexta-feira Santa")
      expect(response.body).not_to include("Não é feriado aqui", "Incluir feriado ou ponto facultativo")

      post "/units/#{branch.id}/holidays", params: { unit_holiday: { date: "2027-07-02", name: "Véspera", kind: "holiday" } }
      expect(response).to have_http_status(:forbidden)
      delete "/units/#{branch.id}/holidays/#{day.id}"
      expect(response).to have_http_status(:forbidden)
    end
  end
end
