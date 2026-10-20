require "rails_helper"

# Spec 19, RN-19-020 to RN-19-024 (CA-19-010, D-618): the partner's administrator sees how
# much of the band and of the quotas the portfolio used, each company's usage, and
# downloads the CSV of a month.
RSpec.describe "Partner's usage", type: :request do
  let(:partner) { create(:partner, name: "Aurora Gestão de Pessoas") }
  let(:brand) { create(:brand, owner: partner, commercial_name: "Aurora RH") }
  let(:cnpj) { generate(:cnpj) }
  let(:cpf) { generate(:cpf) }
  let!(:padaria) { Company.create_with_cnpj!(cnpj: cnpj, partner: partner, name: "Padaria Pão Quente", legal_name: "Padaria Pão Quente Ltda") }
  let!(:sitio) { create(:company, partner: partner, name: "Sítio Boa Vista", employer_type: "person", document: cpf) }
  let!(:admin) { enable_mfa(create(:user, name: "Paula Admin", cpf: "98765432100")) }
  let(:hr) { create(:user) }

  around { |example| travel_to(Time.zone.local(2026, 11, 2, 10)) { example.run } }

  before do
    create(:membership, user: admin, organization: partner, roles: %w[partner_admin])
    brand.subdomains.create!(slug: "aurora")
    Flipper.enable(FeatureFlags::SIGN_IN)
    Flipper.enable(FeatureFlags::BILLING)
    publish_platform_legal_documents
    host! "aurora.painel.catalysthr.com.br"
  end

  def sign_in_as(user, cpf)
    accept_legal_documents(user, brand)
    sign_in_with_mfa(cpf, user)
  end

  def csv_rows
    CSV.parse(response.body.delete_prefix("﻿"), col_sep: ";")
  end

  describe "with the partner under contract" do
    before do
      contract_for(partner).update!(started_on: Date.new(2026, 9, 1))
      [ padaria, sitio ].each { |company| company.update_columns(created_at: Time.zone.local(2026, 9, 1)) }
      position = create_position(padaria)
      2.times { register_employee(padaria, by: hr, position: position) }
      turn_on_modules(padaria, %w[ponto])
      Billing::DailyUsageJob.perform_now(Date.new(2026, 10, 31))
      Billing::ClosePeriodJob.perform_now(Date.new(2026, 11, 1))
      Billing::DailyUsageJob.perform_now(Date.new(2026, 11, 1))
      sign_in_as(admin, "98765432100")
    end

    it "shows the current month, partial, with the band, the quotas and each company" do
      get "/partner"
      expect(response.body).to include(">Consumo<")

      get "/partner/usage"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Novembro de 2026", "Outubro de 2026", "Parcial", "01/11/2026", "de 500 na faixa",
        "de 1.000 no mês", "de 2.000 no mês", "Padaria Pão Quente", "Sítio Boa Vista", Cnpj.format(cnpj),
        SensitiveData.mask(cpf, as: :cpf), "Ponto")
      expect(response.body).not_to include(Cpf.format(cpf))
    end

    it "downloads the closed month with one line per company (CA-19-010)" do
      padaria.update_columns(name: "=1+1 Padaria")

      get "/partner/usage", params: { period: "2026-10" }
      expect(response.body).to include("Mês fechado")

      get "/partner/usage.csv", params: { period: "2026-10" }

      expect(response.headers["Content-Disposition"]).to include("consumo-2026-10.csv")
      expect(response.media_type).to eq("text/csv")
      expect(csv_rows).to eq([
        [ "CNPJ/CPF", "Empresa", "Pico de colaboradores", "Módulos", "Créditos de IA", "Mensagens de WhatsApp" ],
        [ Cnpj.format(cnpj), "'=1+1 Padaria", "2", "Ponto", "0", "0" ],
        [ SensitiveData.mask(cpf, as: :cpf), "Sítio Boa Vista", "0", "", "0", "0" ]
      ])
    end

    it "names the current month's file as partial" do
      get "/partner/usage.csv"

      expect(response.headers["Content-Disposition"]).to include("consumo-2026-11-parcial.csv")
      expect(csv_rows.size).to eq(3)
    end

    it "shows the reduced quotas and no band in the pre-activation (RN-19-035)" do
      partner.subscription.update!(activated_on: nil, pre_activation_price: create(:pre_activation_price))

      get "/partner/usage"

      expect(response.body).to include("de 100 no mês", "Pré-ativação")
      expect(response.body).not_to include("na faixa")
    end
  end

  it "tells the partner without a contract to talk to the CatalystHR team" do
    sign_in_as(admin, "98765432100")

    get "/partner/usage"
    expect(response.body).to include("ainda não tem um contrato")

    get "/partner/usage.csv"
    expect(response).to have_http_status(:not_found)
  end

  it "keeps the usage closed to the consultant (spec 19, section 6)" do
    contract_for(partner)
    consultant = enable_mfa(create(:user, name: "Caio Consultor", cpf: "52998224725"))
    create(:membership, user: consultant, organization: partner, roles: %w[consultant])
    sign_in_as(consultant, "52998224725")

    get "/partner"
    expect(response.body).not_to include(">Consumo<")
    get "/partner/usage"
    expect(response).to have_http_status(:forbidden)
  end

  it "hides the usage while billing is off (D-610)" do
    contract_for(partner)
    Flipper.disable(FeatureFlags::BILLING)
    sign_in_as(admin, "98765432100")

    get "/partner"
    expect(response.body).not_to include(">Consumo<")
    get "/partner/usage"
    expect(response).to have_http_status(:not_found)
  end
end
