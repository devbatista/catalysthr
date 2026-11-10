require "rails_helper"

# Spec 18, block 18d-2 (D-665, D-666): the assisted import. The HR administrator authorizes
# the support for 30 days and revokes it (RN-18-061); without it the admin area blocks
# (CA-18-010); with it, the support or the superadmin imports with the same flow and kinds
# (RN-18-060), the trail keeps who did it and the company sees "Importado pelo suporte
# CatalystHR", with a notice to its HR administrators (RN-18-062).
RSpec.describe "Assisted imports", type: :request do
  include ActiveJob::TestHelper

  let(:company) { create(:company, name: "Metalúrgica Serra Azul") }
  let(:brand) { create(:brand, owner: company, commercial_name: "Serra Azul RH") }
  let!(:hr_user) { enable_mfa(create(:user, name: "Juliana Ribeiro", cpf: "98765432100")) }
  let!(:hr) { create(:membership, user: hr_user, organization: company, roles: %w[hr_admin]) }
  let!(:support) { enable_mfa(create(:user, name: "Sofia Suporte", cpf: "52998224725", platform_role: "support")) }
  let(:xlsx) { "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet" }

  before do
    travel_to Time.zone.local(2026, 11, 10, 10)
    brand.subdomains.create!(slug: "serraazul")
    Flipper.enable(FeatureFlags::SIGN_IN)
    Flipper.enable(FeatureFlags::DATA_IMPORTS)
    publish_platform_legal_documents
  end

  after { travel_back }

  def in_company(&) = ActsAsTenant.with_tenant(company, &)

  def sign_in_panel
    host! "serraazul.painel.catalysthr.com.br"
    accept_legal_documents(hr_user, brand)
    sign_in_with_mfa(hr_user.cpf, hr_user)
  end

  def sign_in_admin(user = support)
    host! "admin.catalysthr.com.br"
    sign_in_with_mfa(user.cpf, user)
  end

  def authorize_in_panel
    sign_in_panel
    post "/confirm-password", params: { password: "Catalyst#2026", return_to: "/imports" }
    post "/imports/assisted-authorization", params: { acceptance: "1" }
  end

  def workbook(title, rows)
    package = Axlsx::Package.new
    package.workbook.add_worksheet(name: title) { |sheet| rows.each { |row| sheet.add_row(row, types: Array.new(row.size, :string)) } }
    Rack::Test::UploadedFile.new(StringIO.new(package.to_stream.read), xlsx, original_filename: "estrutura.xlsx")
  end

  let(:units) { workbook("Unidades", [ [ "Código", "Nome da unidade" ], [ "CAX", "Caxias do Sul" ] ]) }

  it "is authorized by the HR administrator with the password and the acceptance, and revoked (RN-18-061)" do
    sign_in_panel
    get "/imports"
    expect(response.body).to include("Importação assistida pelo suporte CatalystHR", "Autorizar por 30 dias")

    post "/imports/assisted-authorization", params: { acceptance: "1" }
    expect(response).to redirect_to(%r{/confirm-password})
    post "/confirm-password", params: { password: "Catalyst#2026", return_to: "/imports" }
    post "/imports/assisted-authorization"
    expect(in_company { AssistedImportAuthorization.count }).to eq(0)

    post "/imports/assisted-authorization", params: { acceptance: "1" }
    authorization = in_company { AssistedImportAuthorization.current }
    expect([ authorization.authorized_by, authorization.valid_until ]).to eq([ hr_user, Time.zone.local(2026, 12, 10, 10) ])
    expect(AccessEvent.where(action: "assisted_import_authorized", subject: authorization)).to exist
    get "/imports"
    expect(response.body).to include("Autorizada por Juliana Ribeiro em 10/11/2026, até 10/12/2026.")

    delete "/imports/assisted-authorization"
    expect(in_company { AssistedImportAuthorization.current }).to be_nil
    expect(authorization.reload.revoked_by).to eq(hr_user)
  end

  it "blocks the support without a valid authorization (CA-18-010)" do
    sign_in_admin
    get "/assisted-imports", params: { q: "Serra Azul" }
    expect(response.body).to include("Metalúrgica Serra Azul", "Sem autorização do RH administrador")
    expect(response.body).not_to include("/companies/#{company.id}/imports\"")

    get "/companies/#{company.id}/imports"
    expect(response.body).to include("A empresa não autorizou a importação assistida")
    expect(response.body).not_to include("Baixar o modelo", "Histórico")
    post "/companies/#{company.id}/imports", params: { kind: "structure", file: units }
    expect(response).to redirect_to("/companies/#{company.id}/imports")
    expect(in_company { DataImport.count }).to eq(0)
  end

  it "imports on the company's behalf, marked as the support's, and tells the HR administrator (RN-18-060, RN-18-062)" do
    authorize_in_panel
    sign_in_admin
    get "/companies/#{company.id}/imports"
    expect(response.body).to include("Importações de Metalúrgica Serra Azul", "Autorizada por Juliana Ribeiro até 10/12/2026.", "Estrutura",
      "Colaboradores e vínculos")

    perform_enqueued_jobs(only: Imports::ValidateJob) { post "/companies/#{company.id}/imports", params: { kind: "structure", file: units } }
    import = in_company { DataImport.sole }
    expect(response).to redirect_to("/companies/#{company.id}/imports/#{import.id}")
    expect([ import.assisted, import.created_by ]).to eq([ true, support ])

    get "/companies/#{company.id}/imports/#{import.id}"
    expect(response.body).to include("estrutura.xlsx, enviado por Sofia Suporte")
    perform_enqueued_jobs(only: Imports::ApplyJob) { patch "/companies/#{company.id}/imports/#{import.id}/confirm" }
    expect(import.reload).to be_completed
    unit = in_company { Unit.with_code("CAX").sole }
    expect(PaperTrail::Version.where(item: unit).last.whodunnit).to eq(support.id.to_s)

    notice = Notification.find_by!(notification_type: "imports.assisted_completed", recipient_user: hr_user)
    expect([ notice.title, notice.path ]).to eq([ "Importação do suporte: Estrutura", "/imports/#{import.id}" ])
    expect(notice.body).to eq("1 criados, 0 atualizados e 0 com erro. Confira o resultado e, se precisar, desfaça.")

    sign_in_panel
    get "/imports"
    expect(response.body).to include("Importado pelo suporte CatalystHR")
    expect(response.body).not_to include("Sofia Suporte")
    get "/imports/#{import.id}"
    expect(response.body).to include("estrutura.xlsx, importado pelo suporte CatalystHR", "Desfazer a importação")
  end

  it "asks the team's password for people's data and the support's own declaration for accounts (RN-18-041, P-04-17, D-666)" do
    profile = register_employee(company, by: hr_user, position: create_position(company), cpf: "86288366757")
    authorize_in_panel
    sign_in_admin
    get "/companies/#{company.id}/imports/new", params: { kind: "bank_accounts" }
    expect(response).to redirect_to(%r{\A.*/confirm-password\?return_to=})
    post "/confirm-password", params: { password: "Catalyst#2026", return_to: "/companies/#{company.id}/imports/new?kind=bank_accounts" }
    expect(response).to redirect_to("/companies/#{company.id}/imports/new?kind=bank_accounts")

    file = workbook("Dados bancários", [ [ "CPF", "Tipo de chave PIX", "Chave PIX" ], [ "86288366757", "e-mail", "edu@example.com" ] ])
    perform_enqueued_jobs(only: Imports::ValidateJob) { post "/companies/#{company.id}/imports", params: { kind: "bank_accounts", file: file } }
    import = in_company { DataImport.sole }
    get "/companies/#{company.id}/imports/#{import.id}"
    expect(response.body).to include("conforme os arquivos enviados pela empresa")

    perform_enqueued_jobs(only: Imports::ApplyJob) { patch "/companies/#{company.id}/imports/#{import.id}/confirm", params: { declaration: "1" } }
    expect(import.reload).to be_completed
    expect(in_company { profile.bank_accounts.sole.declared_by }).to eq(support)

    get "/companies/#{company.id}/imports/#{import.id}/errors"
    expect(response.media_type).to eq(xlsx)
    expect(AccessEvent.where(kind: "download", action: "import_errors", user: support)).to exist
  end

  it "stops at the end of the 30 days, and is open to the superadmin but not to the finance team" do
    authorize_in_panel
    superadmin = enable_mfa(create(:user, name: "Sara Admin", cpf: "11144477735", platform_role: "superadmin"))
    sign_in_admin(superadmin)
    get "/companies/#{company.id}/imports"
    expect(response.body).to include("Baixar o modelo")

    in_company { AssistedImportAuthorization.current.update!(valid_until: 1.minute.ago) }
    get "/companies/#{company.id}/imports/new", params: { kind: "structure" }
    expect(response).to redirect_to("/companies/#{company.id}/imports")

    finance = enable_mfa(create(:user, name: "Fábio Finanças", cpf: "39053344705", platform_role: "finance"))
    reset!
    sign_in_admin(finance)
    get "/assisted-imports"
    expect(response).not_to have_http_status(:ok)
  end
end
