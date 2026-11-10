require "rails_helper"

# Spec 18, block 18f-2 (D-668, D-669): mass updates as revisions with the date and the reason
# (P-18-14, D-207), by the file or the screen (RN-18-030), with the new reason "Reajuste
# coletivo" (CA-18-008), the percentage rounded to the cent with the half up (D-669) and the
# HR analyst's U scope, the salary only with the payroll module (RN-18-040, CA-18-005, P-03-16).
RSpec.describe "Data imports of mass updates", type: :request do
  include ActiveJob::TestHelper

  let(:company) { create(:company, name: "Metalúrgica Serra Azul") }
  let(:brand) { create(:brand, owner: company, commercial_name: "Serra Azul RH") }
  let!(:hr_user) { enable_mfa(create(:user, name: "Juliana Ribeiro", cpf: "98765432100")) }
  let!(:hr) { create(:membership, user: hr_user, organization: company, roles: %w[hr_admin]) }
  let!(:operator) { create_position(company, name: "Operador", cbo_code: "414105").tap { |record| in_company { record.update!(code: "OPR") } } }
  let!(:analyst_position) { create_position(company, name: "Analista", cbo_code: "252405").tap { |record| in_company { record.update!(code: "ANL") } } }
  let(:caxias) { company.headquarters }
  let!(:bento) { in_company { Unit.create!(name: "Bento Gonçalves", code: "BEN") } }
  let!(:bento_production) { in_company { Department.create!(name: "Produção Bento", code: "PRODB", unit: bento) } }
  let!(:caxias_production) { in_company { Department.create!(name: "Produção Caxias", code: "PRODC", unit: caxias) } }
  let(:xlsx) { "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet" }
  let(:headers) { [ "CPF", "Matrícula", "Vigente a partir de", "Motivo", "Salário novo", "Percentual de reajuste", "Código do cargo", "Código da unidade", "Código do departamento" ] }

  before do
    travel_to Time.zone.local(2026, 11, 10, 10)
    brand.subdomains.create!(slug: "serraazul")
    Flipper.enable(FeatureFlags::SIGN_IN)
    Flipper.enable(FeatureFlags::DATA_IMPORTS)
    publish_platform_legal_documents
    in_company { caxias.update!(code: "MTZ") }
    host! "serraazul.painel.catalysthr.com.br"
  end

  after { travel_back }

  def in_company(&) = ActsAsTenant.with_tenant(company, &)

  def sign_in_as(user)
    accept_legal_documents(user, brand)
    sign_in_with_mfa(user.cpf, user)
    post "/confirm-password", params: { password: "Catalyst#2026", return_to: "/imports" }
  end

  def workbook(rows)
    package = Axlsx::Package.new
    package.workbook.add_worksheet(name: "Atualizações") { |sheet| rows.each { |row| sheet.add_row(row, types: Array.new(row.size, :string)) } }
    Rack::Test::UploadedFile.new(StringIO.new(package.to_stream.read), xlsx, original_filename: "atualizacoes.xlsx")
  end

  def send_file(rows)
    perform_enqueued_jobs(only: Imports::ValidateJob) { post "/imports", params: { kind: "mass_updates", file: workbook(rows) } }
    in_company { DataImport.order(:id).last }
  end

  def confirm(import, **params)
    perform_enqueued_jobs(only: Imports::ApplyJob) { patch "/imports/#{import.id}/confirm", params: params }
    import.reload
  end

  def employee(cpf, salary:, position: operator, unit: caxias, department: caxias_production, name: "Pessoa #{cpf.last(3)}")
    register_employee(company, by: hr_user, position: position, cpf: cpf, salary: salary, unit: unit, department: department, name: name)
  end

  def number(profile) = in_company { profile.employments.sole.registration_number }

  it "gives the operators 5% from 01/05 with the reason Reajuste coletivo, from the screen (CA-18-008, RN-18-030, D-669)" do
    ana = employee("52998224725", salary: "2.000,00")
    bia = employee("11144477735", salary: "2.345,67")
    other = employee("39053344705", salary: "5.000,00", position: analyst_position)
    sign_in_as(hr_user)

    get "/imports/mass-update/new"
    expect(response.body).to include("Atualização em massa pela tela", "Reajuste coletivo", "Percentual de reajuste")

    perform_enqueued_jobs(only: Imports::ValidateJob) do
      post "/imports/mass-update", params: { filters: { position_id: operator.id },
        changes: { effective_on: "2027-05-01", reason: "collective_raise", percent: "5" } }
    end
    import = in_company { DataImport.sole }
    expect(response).to redirect_to("/imports/#{import.id}")
    expect([ import.kind, import.original_filename, import.row_count, import.created_count, import.error_count ])
      .to eq([ "mass_updates", "Atualização pela tela", 2, 2, 0 ])
    raw = DataImport.connection.select_value("SELECT screen FROM data_imports WHERE id = '#{import.id}'")
    expect(raw).not_to include("collective_raise")

    get "/imports/#{import.id}"
    expect(response.body).to include("Cada linha vira uma revisão do vínculo")

    expect(confirm(import)).to be_completed
    in_company do
      [ [ ana, 210_000 ], [ bia, 246_295 ] ].each do |profile, cents|
        revision = profile.employments.sole.revisions.order(:effective_on).last
        expect(revision.attributes.slice("effective_on", "reason", "salary_cents"))
          .to eq("effective_on" => Date.new(2027, 5, 1), "reason" => "collective_raise", "salary_cents" => cents)
      end
      expect(other.employments.sole.revisions.count).to eq(1)
    end
  end

  it "updates by the registration or the CPF, refusing what it cannot apply, and is harmless when sent again (D-669)" do
    ana = employee("52998224725", salary: "2.000,00")
    bia = employee("11144477735", salary: "2.500,00")
    in_company do
      EmploymentRegistration.new(kind: "clt", registration_number: "900", started_on: Date.new(2026, 6, 1), position_id: operator.id,
        unit_id: caxias.id, salary: "1.000,00").save(profile: bia, by: hr_user)
    end
    sign_in_as(hr_user)
    rows = [ headers,
      [ "", number(ana), "01/12/2026", "Promoção", "", "", "ANL" ],
      [ "529.982.247-25", "", "01/12/2027", "Transferência", "", "", "", "BEN", "PRODB" ],
      [ "11144477735", "", "01/12/2026", "Alteração salarial", "3.000,00" ],
      [ "", number(ana), "01/01/2027", "Alteração salarial", "3.000,00", "5" ],
      [ "", number(ana), "01/02/2027", "Transferência", "", "", "", "BEN" ] ]
    import = send_file(rows)
    expect([ import.created_count, import.error_count ]).to eq([ 2, 3 ])

    get "/imports/#{import.id}"
    expect(response.body).to include("Esta pessoa tem mais de um vínculo aberto. Preencha a matrícula.",
      "Preencha o salário novo ou o percentual, não os dois.", "Preencha o departamento da unidade nova.")

    confirm(import, only_valid: "1")
    in_company do
      employment = ana.employments.sole.reload
      expect(employment.revision_on(Date.new(2026, 12, 2)).position).to eq(analyst_position)
      expect(employment.revision_on(Date.new(2027, 12, 2)).attributes.slice("unit_id", "department_id", "position_id"))
        .to eq("unit_id" => bento.id, "department_id" => bento_production.id, "position_id" => analyst_position.id)
    end

    again = send_file(rows.first(3))
    expect([ again.unchanged_count, again.valid_count ]).to eq([ 2, 0 ])
  end

  it "keeps the HR analyst in their units and out of the salary without the payroll module (RN-18-040, CA-18-005, P-03-16)" do
    ana = employee("52998224725", salary: "2.000,00")
    bruno = employee("86288366757", salary: "2.000,00", unit: bento, department: bento_production)
    analyst_user = enable_mfa(create(:user, name: "Rui Costa", cpf: "39053344705"))
    analyst = create(:membership, user: analyst_user, organization: company, roles: %w[hr_analyst], status: "active", enabled_modules: %w[documentos])
    in_company { Memberships::AssignUnits.call(membership: analyst, unit_ids: [ caxias.id ], by: hr_user) }
    sign_in_as(analyst_user)

    get "/imports/mass-update/new"
    expect(response.body).not_to include("Percentual de reajuste", "Bento Gonçalves")

    import = send_file([ headers,
      [ "", number(bruno), "01/12/2026", "Promoção", "", "", "ANL" ],
      [ "", number(ana), "01/12/2026", "Transferência", "", "", "", "BEN", "PRODB" ],
      [ "", number(ana), "01/01/2027", "Alteração salarial", "", "5" ],
      [ "", number(ana), "01/02/2027", "Promoção", "", "", "ANL" ] ])
    expect([ import.valid_count, import.error_count ]).to eq([ 1, 3 ])

    get "/imports/#{import.id}"
    expect(response.body).to include("fora do seu escopo. Você só atualiza vínculos das suas unidades",
      "sem permissão para salário")

    get "/imports"
    expect(response.body).to include("Atualizações em massa")
    expect(response.body).not_to include("Estrutura")
  end
end
