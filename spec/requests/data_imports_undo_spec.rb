require "rails_helper"

# Spec 18, block 18d-1 (D-665): undoing a whole import while nothing of it was used
# (RN-18-050 to RN-18-052, CA-18-009). The records created are deleted, even a revision in
# force; the ones changed get back their values, sensitive ones included (D-086); what blocks
# is listed, and nothing changes.
RSpec.describe "Undoing data imports", type: :request do
  include ActiveJob::TestHelper

  let(:company) { create(:company, name: "Metalúrgica Serra Azul") }
  let(:brand) { create(:brand, owner: company, commercial_name: "Serra Azul RH") }
  let!(:hr_user) { enable_mfa(create(:user, name: "Juliana Ribeiro", cpf: "98765432100")) }
  let!(:hr) { create(:membership, user: hr_user, organization: company, roles: %w[hr_admin]) }
  let!(:position) { create_position(company, salary_min_cents: 100_000, salary_max_cents: 350_000).tap { |record| in_company { record.update!(code: "ANL") } } }
  let(:xlsx) { "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet" }
  let(:employee_headers) { [ "CPF", "Nome completo", "Data de nascimento", "Matrícula", "Data de admissão", "Código do cargo", "Código da unidade", "Salário", "E-mail de acesso" ] }

  before do
    travel_to Time.zone.local(2026, 11, 10, 10)
    brand.subdomains.create!(slug: "serraazul")
    Flipper.enable(FeatureFlags::SIGN_IN)
    Flipper.enable(FeatureFlags::DATA_IMPORTS)
    publish_platform_legal_documents
    in_company { company.headquarters.update!(code: "MTZ") }
    host! "serraazul.painel.catalysthr.com.br"
    accept_legal_documents(hr_user, brand)
    sign_in_with_mfa(hr_user.cpf, hr_user)
    post "/confirm-password", params: { password: "Catalyst#2026", return_to: "/imports" }
  end

  after { travel_back }

  def in_company(&) = ActsAsTenant.with_tenant(company, &)

  def workbook(title, rows)
    package = Axlsx::Package.new
    package.workbook.add_worksheet(name: title) { |sheet| rows.each { |row| sheet.add_row(row, types: Array.new(row.size, :string)) } }
    Rack::Test::UploadedFile.new(StringIO.new(package.to_stream.read), xlsx, original_filename: "planilha.xlsx")
  end

  def import!(kind, title, rows, **params)
    perform_enqueued_jobs(only: Imports::ValidateJob) { post "/imports", params: { kind: kind, file: workbook(title, rows) } }
    import = in_company { DataImport.order(:id).last }
    perform_enqueued_jobs(only: Imports::ApplyJob) { patch "/imports/#{import.id}/confirm", params: params }
    import.reload
  end

  def undo(import)
    perform_enqueued_jobs(only: Imports::UndoJob) { patch "/imports/#{import.id}/undo" }
    import.reload
  end

  it "deletes the people it created and keeps who already had an account (RN-18-052, D-665)" do
    other_company = create(:company, name: "Padaria Pão Quente")
    rita = register_employee(other_company, by: hr_user, position: create_position(other_company), name: "Rita Souza", cpf: "11144477735")
    import = import!("employees", "Colaboradores", [ employee_headers,
      [ "52998224725", "Ana Lima", "1990-05-10", "1", "2018-03-01", "ANL", "MTZ", "2.500,00", "ana@example.com" ],
      [ "11144477735", "Rita Souza", "1980-01-01", "2", "2020-04-01", "ANL", "MTZ", "3.000,00" ] ])
    expect(import).to be_completed
    expect(in_company { [ WorkerProfile.count, Employment.count, EmploymentRevision.count ] }).to eq([ 2, 2, 2 ])

    get "/imports/#{import.id}"
    expect(response.body).to include("Desfazer a importação")

    import = undo(import)
    expect(import).to be_undone
    expect(import.undone_by).to eq(hr_user)
    expect(in_company { [ WorkerProfile.count, Employment.count, EmploymentRevision.count ] }).to eq([ 0, 0, 0 ])
    expect(User.find_by(cpf: "52998224725")).to be_nil
    expect(User.find_by(cpf: "11144477735")).to eq(rita.user)
    expect(Membership.where(user: rita.user).pluck(:organization_id)).to eq([ other_company.id ])
    expect(PaperTrail::Version.where(request_id: "undo:#{import.id}", event: "destroy")).to exist
    expect(AccessEvent.where(kind: "import", action: "undo", subject: import)).to exist

    get "/imports/#{import.id}"
    expect(response.body).to include("Importação desfeita por Juliana Ribeiro", "Desfeita")
    expect(response.body).not_to include("Desfazer a importação inteira?")
  end

  it "refuses when someone accepted the invitation and shows who, changing nothing (RN-18-050, RN-18-051, CA-18-009)" do
    import = import!("employees", "Colaboradores", [ employee_headers,
      [ "52998224725", "Ana Lima", "1990-05-10", "1", "2018-03-01", "ANL", "MTZ", "2.500,00", "ana@example.com" ],
      [ "39053344705", "Caio Melo", "1990-05-10", "2", "2018-03-01", "ANL", "MTZ", "2.500,00", "caio@example.com" ] ])
    in_company { Membership.joins(:user).find_by!(users: { cpf: "52998224725" }, organization: company).update!(status: "active") }

    import = undo(import)
    expect(import).to be_completed
    expect(import.undo_blockers).to eq([ { "record" => "Ana Lima", "message" => "aceitou o convite e já acessa o portal." } ])
    expect(in_company { WorkerProfile.count }).to eq(2)

    get "/imports/#{import.id}"
    expect(response.body).to include("A importação não pode ser desfeita", "Ana Lima", "aceitou o convite")
  end

  it "lists a record created later that points to one of the import, and a record changed later" do
    import = import!("structure", "Unidades", [ [ "Código", "Nome da unidade" ], [ "CAX", "Caxias do Sul" ], [ "BEN", "Bento Gonçalves" ] ])
    in_company do
      Department.create!(name: "Produção", unit: Unit.with_code("CAX").sole)
      travel 1.minute
      Unit.with_code("BEN").sole.update!(name: "Bento")
    end

    import = undo(import)
    expect(import.undo_blockers.map { |blocker| [ blocker["record"], blocker["message"] ] }).to contain_exactly(
      [ "Unidade CAX", "tem cadastro ligado criado depois da importação (Departamento)." ],
      [ "Unidade BEN", "mudou depois da importação." ]
    )
    expect(in_company { Unit.with_code("CAX") }).to exist
  end

  it "gives back the values PaperTrail does not keep and the previous primary account (D-086, CA-04-008)" do
    profile = register_employee(company, by: hr_user, position: position, cpf: "52998224725")
    dependent, old_account = in_company do
      [ profile.dependents.create!(name: "Pedro Lima", birth_date: Date.new(2015, 4, 2), relationship_type: "child"),
        BankAccounts::Register.call(profile: profile, attributes: { bank_code: "001", branch: "1234", account_number: "56789", account_type: "checking" },
          primary: true, by: hr_user) ]
    end
    travel 1.minute
    dependents = import!("dependents", "Dependentes", [ [ "CPF do titular", "Nome do dependente", "Data de nascimento", "Parentesco", "CPF do dependente", "Dependente para o IRRF" ],
      [ "52998224725", "Pedro Lima", "02/04/2015", "Filho(a)", "390.533.447-05", "Sim" ] ])
    accounts = import!("bank_accounts", "Dados bancários", [ [ "CPF", "Código do banco", "Agência", "Conta", "Tipo de conta" ],
      [ "52998224725", "341", "0001", "998876", "Conta corrente" ] ], declaration: "1")
    expect(in_company { [ dependent.reload.cpf, old_account.reload.status ] }).to eq([ "39053344705", "ended" ])

    expect(undo(accounts)).to be_undone
    expect(undo(dependents)).to be_undone
    in_company do
      expect(dependent.reload.attributes.slice("cpf", "irrf")).to eq("cpf" => nil, "irrf" => false)
      expect(old_account.reload.attributes.slice("status", "primary", "ended_on")).to eq("status" => "active", "primary" => true, "ended_on" => nil)
      expect(profile.bank_accounts.count).to eq(1)
    end
  end

  it "deletes the corrections of the history, even in force (D-603, D-665)" do
    profile = register_employee(company, by: hr_user, position: position, cpf: "52998224725", salary: "2.500,00", started_on: Date.new(2018, 3, 1))
    number = in_company { profile.employments.sole.registration_number }
    import = import!("employment_history", "Histórico", [ [ "CPF", "Matrícula", "Vigente a partir de", "Motivo", "Salário" ],
      [ "52998224725", number, "01/03/2018", "Alteração salarial", "1.500,00" ],
      [ "52998224725", number, "01/05/2022", "Alteração salarial", "2.500,00" ] ])
    expect(in_company { profile.employments.sole.revisions.count }).to eq(3)

    expect(undo(import)).to be_undone
    in_company { expect(profile.employments.sole.revisions.pluck(:reason)).to eq(%w[admission]) }
  end

  it "is no longer possible after the 90 days, nor for the HR analyst (RN-18-010, RN-18-050)" do
    import = import!("structure", "Unidades", [ [ "Código", "Nome da unidade" ], [ "CAX", "Caxias do Sul" ] ])
    travel 91.days
    Imports::PurgeJob.perform_now
    patch "/imports/#{import.id}/undo"
    expect(import.reload).to be_completed
    expect(in_company { Unit.with_code("CAX") }).to exist
    expect(Imports::Undo.available?(import)).to be(false)
  end
end
