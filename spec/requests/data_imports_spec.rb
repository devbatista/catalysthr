require "rails_helper"

# Spec 18, block 18a (D-661, D-662): the common engine with the structure's kind. The
# template, the sending, the preview with the errors line by line, nothing recorded before
# the confirmation (D-462), everything or only the valid lines (CA-18-001, CA-18-002), the
# update without erasing (RN-18-007), the references inside the file (RN-18-005), the trail
# with the origin (RN-18-009) and the 90 days (RN-18-010).
RSpec.describe "Data imports", type: :request do
  include ActiveJob::TestHelper

  let(:company) { create(:company, name: "Metalúrgica Serra Azul") }
  let(:brand) { create(:brand, owner: company, commercial_name: "Serra Azul RH") }
  let!(:hr_user) { enable_mfa(create(:user, name: "Juliana Ribeiro", cpf: "98765432100")) }
  let!(:hr) { create(:membership, user: hr_user, organization: company, roles: %w[hr_admin]) }
  let(:xlsx) { "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet" }

  before do
    travel_to Time.zone.local(2026, 11, 10, 10)
    brand.subdomains.create!(slug: "serraazul")
    Flipper.enable(FeatureFlags::SIGN_IN)
    Flipper.enable(FeatureFlags::DATA_IMPORTS)
    publish_platform_legal_documents
    CboOccupation.find_or_create_by!(code: "252405") { |occupation| occupation.title = "Analista de recursos humanos" }
    CboOccupation.find_or_create_by!(code: "414105") { |occupation| occupation.title = "Almoxarife" }
    host! "serraazul.painel.catalysthr.com.br"
  end

  after { travel_back }

  def in_company(&) = ActsAsTenant.with_tenant(company, &)

  def sign_in_hr(user = hr_user)
    accept_legal_documents(user, brand)
    sign_in_with_mfa(user.cpf, user)
  end

  # An XLSX with the given tabs: { "Unidades" => [ headers, *rows ] }.
  def workbook(tabs)
    package = Axlsx::Package.new
    tabs.each do |title, rows|
      package.workbook.add_worksheet(name: title) { |sheet| rows.each { |row| sheet.add_row(row, types: Array.new(row.size, :string)) } }
    end
    Rack::Test::UploadedFile.new(StringIO.new(package.to_stream.read), xlsx, original_filename: "estrutura.xlsx")
  end

  def send_file(file)
    perform_enqueued_jobs(only: Imports::ValidateJob) { post "/imports", params: { kind: "structure", file: file } }
    in_company { DataImport.order(:id).last }
  end

  def confirm(import, only_valid: false)
    perform_enqueued_jobs(only: Imports::ApplyJob) do
      patch "/imports/#{import.id}/confirm", params: { only_valid: (only_valid ? "1" : nil) }.compact
    end
    import.reload
  end

  def positions_tab(rows)
    { "Cargos" => [ [ "Código", "Nome do cargo", "CBO", "Salário mínimo" ], *rows ] }
  end

  it "stays out of the menu and answers 404 while the flag is off (D-661)" do
    Flipper.disable(FeatureFlags::DATA_IMPORTS)
    sign_in_hr
    get "/"
    expect(response.body).not_to include("/imports")
    get "/imports"
    expect(response).to have_http_status(:not_found)
  end

  it "gives the template with the instructions, the three tabs and the lists (RN-18-001, D-662)" do
    sign_in_hr
    get "/imports"
    expect(response.body).to include("Importações", "Estrutura", "Baixar o modelo", "/imports/templates/structure")

    get "/imports/templates/structure"
    expect(response.media_type).to eq(xlsx)
    path = Rails.root.join("tmp/estrutura-#{SecureRandom.hex(4)}.xlsx")
    File.binwrite(path, response.body)
    book = Roo::Excelx.new(path.to_s)
    expect(book.sheets).to eq(%w[Instruções Unidades Departamentos Cargos Listas])
    expect(book.sheet("Departamentos").row(1)).to eq([ "Código", "Nome do departamento", "Código da unidade", "Código do departamento pai" ])
    expect(book.sheet("Listas").row(1)).to include("CNPJ", "AC", "America/Sao_Paulo")
  ensure
    FileUtils.rm_f(path) if path
  end

  it "shows 297 valid lines and 3 errors with line, column and message, and records nothing (CA-18-001)" do
    sign_in_hr
    rows = (1..300).map { |number| [ "CAR#{number}", "Cargo #{number}", number % 100 == 0 ? "999999" : "252405", "2.500,00" ] }
    import = send_file(workbook(positions_tab(rows)))

    expect(import).to be_preview
    expect([ import.row_count, import.valid_count, import.error_count, import.created_count ]).to eq([ 300, 297, 3, 297 ])
    expect(in_company { Position.count }).to eq(0)

    get "/imports/#{import.id}"
    expect(response.body).to include("Aguardando confirmação", "Cargos, linha 101", "CBO", "999999", "Importar só as 297 válidas")
    expect(response.body).not_to include("Importar tudo")
    expect(Nokogiri::HTML(response.body).css("[data-error-line]").map { |row| row["data-error-line"] }).to eq(%w[101 201 301])
    expect(AccessEvent.where(kind: "import", action: "upload", subject: import)).to exist
  end

  it "imports only the valid lines and lists the rejected ones (CA-18-002)" do
    sign_in_hr
    rows = (1..300).map { |number| [ "CAR#{number}", "Cargo #{number}", number % 100 == 0 ? "999999" : "252405", "2.500,00" ] }
    import = send_file(workbook(positions_tab(rows)))

    patch "/imports/#{import.id}/confirm"
    expect(response).to redirect_to("/imports/#{import.id}")
    expect(import.reload).to be_preview

    import = confirm(import, only_valid: true)
    expect(import).to be_completed_with_errors
    expect([ import.created_count, import.error_count, import.failed_count ]).to eq([ 297, 3, 0 ])
    in_company do
      expect(Position.count).to eq(297)
      expect(Position.with_code("CAR1").sole.salary_min_cents).to eq(250_000)
    end
    expect(AccessEvent.where(kind: "import", action: "confirm", subject: import)).to exist

    get "/imports/#{import.id}/errors"
    path = Rails.root.join("tmp/erros-#{SecureRandom.hex(4)}.xlsx")
    File.binwrite(path, response.body)
    sheet = Roo::Excelx.new(path.to_s).sheet("Cargos")
    expect(sheet.row(1).last).to eq("Erros")
    expect((2..sheet.last_row).map { |line| sheet.row(line).last }.compact.size).to eq(3)
    expect(AccessEvent.where(kind: "download", action: "import_errors")).to exist
  ensure
    FileUtils.rm_f(path) if path
  end

  it "updates by the code without erasing what an empty cell leaves out, in the trail (RN-18-007, RN-18-009)" do
    unit = in_company { Unit.create!(name: "Filial", code: "FIL", city: "Caxias do Sul", state: "RS") }
    sign_in_hr
    file = workbook("Unidades" => [ [ "Código", "Nome da unidade", "Cidade", "UF" ], [ "fil", "Filial Caxias", "", "RS" ] ])
    import = send_file(file)
    expect([ import.updated_count, import.unchanged_count ]).to eq([ 1, 0 ])

    get "/imports/#{import.id}"
    expect(response.body).to include("O que muda nos cadastros existentes", "Filial", "Filial Caxias", "Importar tudo")

    import = confirm(import)
    expect(import).to be_completed
    expect(unit.reload.attributes.slice("name", "city")).to eq("name" => "Filial Caxias", "city" => "Caxias do Sul")
    version = PaperTrail::Version.where(item: unit).order(:id).last
    expect([ version.request_id, version.whodunnit ]).to eq([ "import:#{import.id}", hr_user.id.to_s ])

    again = send_file(file)
    expect([ again.unchanged_count, again.valid_count ]).to eq([ 1, 0 ])
  end

  it "points departments to units and parents of the same file, in any order (RN-18-005)" do
    in_company { Unit.create!(name: "Matriz antiga", code: "OLD") }
    sign_in_hr
    file = workbook(
      "Unidades" => [ [ "Código", "Nome da unidade" ], [ "CAX", "Caxias do Sul" ], [ "", "Sem código" ] ],
      "Departamentos" => [ [ "Código", "Nome do departamento", "Código da unidade", "Código do departamento pai" ],
        [ "PROD-L1", "Linha 1", "CAX", "PROD" ], [ "PROD", "Produção", "CAX", "" ], [ "VEND", "Vendas", "OLD", "PROD" ],
        [ "A", "Ciclo A", "CAX", "B" ], [ "B", "Ciclo B", "CAX", "A" ], [ "X", "Sem unidade", "NAOEXISTE", "" ] ]
    )
    import = send_file(file)

    get "/imports/#{import.id}"
    body = response.body
    expect(body).to include("Unidades, linha 3", "Código é obrigatório.",
      "O departamento pai precisa ser da mesma unidade.", "Os departamentos pai desta aba voltam para este departamento.",
      "Nenhuma unidade com o código NAOEXISTE")
    expect([ import.valid_count, import.error_count ]).to eq([ 3, 5 ])

    import = confirm(import, only_valid: true)
    in_company do
      production = Department.with_code("PROD").sole
      expect(Department.with_code("PROD-L1").sole.parent).to eq(production)
      expect(production.unit).to eq(Unit.with_code("CAX").sole)
    end
    expect(import.failed_count).to eq(0)
  end

  it "refuses a department changing unit, as the manual form (D-662)" do
    in_company do
      unit = Unit.create!(name: "Caxias", code: "CAX")
      Unit.create!(name: "Bento", code: "BEN")
      Department.create!(name: "Produção", code: "PROD", unit: unit)
    end
    sign_in_hr
    import = send_file(workbook("Departamentos" => [ [ "Código", "Nome do departamento", "Código da unidade" ], [ "PROD", "Produção", "BEN" ] ]))
    get "/imports/#{import.id}"
    expect(response.body).to include("Um departamento cadastrado não muda de unidade.")
  end

  it "takes only the XLSX for the structure and reads the headers by name (D-662, RN-18-003)" do
    sign_in_hr
    csv = Rack::Test::UploadedFile.new(StringIO.new("Código;Nome do cargo;CBO\nC1;Almoxarife;414105\n"), "text/csv", original_filename: "cargos.csv")
    post "/imports", params: { kind: "structure", file: csv }
    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("Esta importação aceita só XLSX.")

    import = send_file(workbook("Cargos" => [ [ "CBO", "nome do cargo*", "código", "Outra" ], [ "414105", "Almoxarife", "alm", "x" ] ]))
    expect([ import.valid_count, import.error_count ]).to eq([ 1, 0 ])

    missing = send_file(workbook("Cargos" => [ [ "Código", "Nome do cargo" ], [ "C2", "Sem CBO" ] ]))
    expect(missing).to be_failed
    expect(missing.failure_reason).to eq("Faltam colunas obrigatórias na aba Cargos: CBO. Use os nomes do modelo no cabeçalho.")
  end

  it "is only the HR administrator's (RN-18-042, D-661)" do
    analyst = enable_mfa(create(:user, name: "Paula Souza", cpf: "86288366757"))
    create(:membership, user: analyst, organization: company, roles: %w[hr_analyst], enabled_modules: %w[admissao documentos])
    sign_in_hr(analyst)
    get "/"
    expect(response.body).not_to include("/imports")
    get "/imports"
    expect(response).not_to have_http_status(:ok)
    get "/imports/templates/structure"
    expect(response).not_to have_http_status(:ok)
  end

  it "keeps the lines' data encrypted and drops them with the file after 90 days (D-661, RN-18-010)" do
    sign_in_hr
    import = send_file(workbook(positions_tab([ [ "C1", "Cargo secreto", "999999", "" ] ])))
    row = in_company { import.rows.sole }
    raw = DataImportRow.connection.select_value("SELECT payload FROM data_import_rows WHERE id = '#{row.id}'")
    expect(raw).not_to include("Cargo secreto")
    expect(row.payload["name"]).to eq("Cargo secreto")

    travel 91.days
    Imports::PurgeJob.perform_now
    Imports::PurgeJob.perform_now
    import.reload
    row.reload
    expect(import.purged_at).to be_present
    expect(import.file).not_to be_attached
    expect(row.payload).to eq({})
    expect(row.issues.first.keys).to eq(%w[column message])
    expect(import.error_count).to eq(1)
  end
end
