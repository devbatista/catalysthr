require "rails_helper"

# Spec 18, block 18f-1 (D-668): admissions in batch, one per line with the minimal initial
# registration (D-254), through the manual rules, without invitation (P-07-06); the HR analyst
# only in their units (RN-18-040, CA-18-005); "Liberar acesso de todos" by e-mail.
RSpec.describe "Admissions in batch", type: :request do
  include ActiveJob::TestHelper

  let(:company) { create(:company, name: "Metalúrgica Serra Azul") }
  let(:brand) { create(:brand, owner: company, commercial_name: "Serra Azul RH") }
  let!(:hr_user) { enable_mfa(create(:user, name: "Juliana Ribeiro", cpf: "98765432100")) }
  let!(:hr) { create(:membership, user: hr_user, organization: company, roles: %w[hr_admin]) }
  let!(:position) { create_position(company, name: "Operador").tap { |record| in_company { record.update!(code: "OPR") } } }
  let(:caxias) { company.headquarters }
  let!(:bento) { in_company { Unit.create!(name: "Bento Gonçalves", code: "BGO") } }
  let!(:production) { in_company { Department.create!(name: "Produção", unit: caxias, code: "PRD") } }
  let!(:assembly) { in_company { Department.create!(name: "Montagem", unit: bento, code: "MNT") } }
  let(:xlsx) { "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet" }
  let(:headers) do
    [ "CPF", "Nome completo", "E-mail de acesso", "Celular de acesso", "Data prevista de início", "Código do cargo",
      "Código da unidade", "Código do departamento", "Salário" ]
  end

  before do
    travel_to Time.zone.local(2026, 11, 10, 10)
    brand.subdomains.create!(slug: "serraazul")
    Flipper.enable(FeatureFlags::SIGN_IN)
    Flipper.enable(FeatureFlags::DATA_IMPORTS)
    Flipper.enable(FeatureFlags::ADMISSIONS)
    publish_platform_legal_documents
    in_company do
      caxias.update!(code: "CXS")
      model = ProcessTemplate.create!(kind: "admission", name: "Admissão padrão")
      model.items.create!(position: 1, kind: "task", title: "Conferir o cadastro", responsible_role: "hr", stage: "registration")
      model.update!(status: "active")
      model.make_default!
    end
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
    package.workbook.add_worksheet(name: "Admissões") { |sheet| rows.each { |row| sheet.add_row(row, types: Array.new(row.size, :string)) } }
    Rack::Test::UploadedFile.new(StringIO.new(package.to_stream.read), xlsx, original_filename: "admissoes.xlsx")
  end

  def send_file(rows)
    perform_enqueued_jobs(only: Imports::ValidateJob) { post "/imports", params: { kind: "admissions", file: workbook(rows) } }
    in_company { DataImport.order(:id).last }
  end

  def confirm(import, **params)
    perform_enqueued_jobs(only: Imports::ApplyJob) { patch "/imports/#{import.id}/confirm", params: params }
    import.reload
  end

  def errors_of(import)
    in_company { import.rows.status_invalid.order(:line_number).map { |row| [ row.line_number, row.issues.map { |issue| issue["message"] } ] } }
  end

  it "creates one admission per line in step 1, without invitation, and releases them all by e-mail (D-254, P-07-06)" do
    sign_in_as(hr_user)
    get "/imports"
    expect(response.body).to include("Admissões em lote")
    get "/imports/templates/admissions"
    expect(response.media_type).to eq(xlsx)

    import = send_file([ headers,
      [ "529.982.247-25", "Ana Lima", "ana@example.com", "", "01/12/2026", "OPR", "CXS", "PRD", "2.500,00" ],
      [ "11144477735", "Bruno Souza", "", "54999990000", "2026-12-01", "OPR", "CXS", "PRD", "" ] ])
    expect(import).to be_preview
    expect(import.error_count).to eq(0)
    expect(in_company { Admission.count }).to eq(0)

    expect { import = confirm(import) }.not_to have_enqueued_mail
    expect(import).to be_completed
    expect(import.created_count).to eq(2)
    admissions = in_company { Admission.includes(employment: { worker_profile: { membership: :user } }).to_a }
    expect(admissions.map { |admission| admission.worker_profile.user.name }).to contain_exactly("Ana Lima", "Bruno Souza")
    in_company do
      expect(admissions).to all(have_attributes(open?: true, invite_released_at: nil))
      expect(admissions.map(&:employment)).to all(have_attributes(status: "pending", started_on: Date.new(2026, 12, 1)))
    end
    expect(in_company { Membership.where(user: admissions.map { |admission| admission.worker_profile.user }).pluck(:status).uniq }).to eq(%w[invited])

    get "/imports/#{import.id}"
    expect(response.body).to include("Liberar acesso de todos", "1 admissão com e-mail espera a liberação do acesso",
      "1 pessoa não tem e-mail", "Bruno Souza")

    expect do
      perform_enqueued_jobs(only: Imports::ReleaseAdmissionsJob) { post "/imports/#{import.id}/release-admissions" }
    end.to change { AccessEvent.where(action: "admission_access_released").count }.by(1)
    expect(in_company { admissions.map { |admission| [ admission.worker_profile.user.name, admission.reload.released? ] }.to_h })
      .to eq("Ana Lima" => true, "Bruno Souza" => false)

    get "/imports/#{import.id}"
    expect(response.body).not_to include("Liberar acesso de todos")
    expect(response.body).to include("1 pessoa não tem e-mail", "/admissions/")

    # Sent again, the same CPFs are errors and nothing is created twice (D-668).
    again = send_file([ headers, [ "52998224725", "Ana Lima", "ana@example.com", "", "01/12/2026", "OPR", "CXS", "PRD", "" ] ])
    expect(errors_of(again)).to eq([ [ 2, [ "Este CPF já tem uma admissão em andamento na empresa. Corrija pela tela da admissão." ] ] ])
  end

  it "shows each line's errors with the manual rules, and imports only the valid ones (RN-18-005, CA-18-001, CA-18-002)" do
    sign_in_as(hr_user)
    import = send_file([ headers,
      [ "52998224725", "Ana Lima", "ana@example.com", "", "01/12/2026", "OPR", "CXS", "PRD", "" ],
      [ "52998224725", "Ana Lima", "ana@example.com", "", "01/12/2026", "OPR", "CXS", "PRD", "" ],
      [ "11144477735", "Bruno Souza", "", "", "01/12/2026", "OPR", "CXS", "PRD", "" ],
      [ "39053344705", "Carla Dias", "carla@example.com", "", "01/11/2026", "OPR", "CXS", "PRD", "" ],
      [ "12345678900", "Davi Reis", "davi@example.com", "", "01/12/2026", "XXX", "CXS", "PRD", "" ] ])
    errors = errors_of(import).to_h
    expect(errors.keys).to eq([ 3, 4, 5, 6 ])
    expect(errors[3]).to include("Este CPF já aparece na linha 2.")
    expect(errors[4].join).to match(/e-mail ou o celular|celular ou e-mail/i)
    expect(errors[5].join).to match(/hoje ou uma data futura/)
    expect(errors[6]).to include("CPF: CPF inválido.", "Nenhum cadastro com o código XXX em Código do cargo.")

    import = confirm(import, only_valid: "1")
    expect(import).to be_completed_with_errors
    expect(import.created_count).to eq(1)
    expect(in_company { Admission.count }).to eq(1)
  end

  it "lets the HR analyst admit only in their units, and see only their own imports (RN-18-040, CA-18-005)" do
    other_import = in_company { DataImport.create!(kind: "structure", created_by: hr_user, original_filename: "estrutura.xlsx", status: "completed") }
    analyst_user = enable_mfa(create(:user, name: "Rui Costa", cpf: "39053344705"))
    analyst = create(:membership, user: analyst_user, organization: company, roles: %w[hr_analyst], status: "active", enabled_modules: %w[admissao])
    in_company { Memberships::AssignUnits.call(membership: analyst, unit_ids: [ caxias.id ], by: hr_user) }
    sign_in_as(analyst_user)

    get "/imports"
    expect(response.body).to include("Admissões em lote")
    expect(response.body).not_to include("Colaboradores e vínculos", "estrutura.xlsx")
    get "/imports/#{other_import.id}"
    expect(response).to have_http_status(:forbidden)

    import = send_file([ headers,
      [ "52998224725", "Ana Lima", "ana@example.com", "", "01/12/2026", "OPR", "CXS", "PRD", "" ],
      [ "11144477735", "Bruno Souza", "bruno@example.com", "", "01/12/2026", "OPR", "BGO", "MNT", "" ] ])
    expect(errors_of(import)).to eq([ [ 3, [ "Código da unidade: fora do seu escopo. Você só admite nas suas unidades." ] ] ])

    import = confirm(import, only_valid: "1")
    expect(import.created_count).to eq(1)
    expect(in_company { Admission.sole.employment.effective_revision.unit }).to eq(caxias)
    patch "/imports/#{import.id}/undo"
    expect(response).to have_http_status(:forbidden)
  end

  it "is not offered without the admissions' module or its flag (D-648)" do
    analyst_user = enable_mfa(create(:user, name: "Rui Costa", cpf: "39053344705"))
    create(:membership, user: analyst_user, organization: company, roles: %w[hr_analyst], status: "active", enabled_modules: %w[documentos])
    sign_in_as(analyst_user)
    get "/imports"
    expect(response).to have_http_status(:forbidden)

    delete "/sign-out"
    Flipper.disable(FeatureFlags::ADMISSIONS)
    sign_in_as(hr_user)
    get "/imports"
    expect(response.body).not_to include("Admissões em lote")
    get "/imports/templates/admissions"
    expect(response).to have_http_status(:not_found)
  end

  it "undoes the whole import while nothing of it was used (RN-18-050, D-665)" do
    sign_in_as(hr_user)
    import = confirm(send_file([ headers, [ "52998224725", "Ana Lima", "ana@example.com", "", "01/12/2026", "OPR", "CXS", "PRD", "" ] ]))
    expect(in_company { [ Admission.count, Employment.count, ProcessInstance.count ] }).to eq([ 1, 1, 1 ])

    perform_enqueued_jobs(only: Imports::UndoJob) { patch "/imports/#{import.id}/undo" }
    expect(import.reload).to be_undone
    expect(in_company { [ Admission.count, Employment.count, ProcessInstance.count, WorkerProfile.count ] }).to eq([ 0, 0, 0, 0 ])
    expect(User.find_by(cpf: "52998224725")).to be_nil
  end
end
