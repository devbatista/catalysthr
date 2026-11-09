require "rails_helper"

# Spec 18, block 18b (D-661, D-663): employees and employments, dependents and bank accounts.
# The manual rules (RN-18-005), no invitation nor eSocial (RN-18-020, CA-18-004), the record's
# own contacts for who exists (CA-18-003, D-602), the conditions of an employment unchanged
# (D-207), the password to send, confirm and download the errors (RN-18-041) and the masked
# values (D-086).
RSpec.describe "Data imports of people", type: :request do
  include ActiveJob::TestHelper

  let(:company) { create(:company, name: "Metalúrgica Serra Azul") }
  let(:brand) { create(:brand, owner: company, commercial_name: "Serra Azul RH") }
  let!(:hr_user) { enable_mfa(create(:user, name: "Juliana Ribeiro", cpf: "98765432100")) }
  let!(:hr) { create(:membership, user: hr_user, organization: company, roles: %w[hr_admin]) }
  let!(:position) { create_position(company, salary_min_cents: 200_000, salary_max_cents: 350_000).tap { |record| in_company { record.update!(code: "ANL") } } }
  let(:xlsx) { "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet" }
  let(:employee_headers) do
    [ "CPF", "Nome completo", "Data de nascimento", "Matrícula", "Data de admissão", "Código do cargo", "Código da unidade",
      "Salário", "E-mail de acesso", "Celular de acesso", "Telefone pessoal", "E-mail pessoal", "Sexo", "RG" ]
  end

  before do
    travel_to Time.zone.local(2026, 11, 10, 10)
    brand.subdomains.create!(slug: "serraazul")
    Flipper.enable(FeatureFlags::SIGN_IN)
    Flipper.enable(FeatureFlags::DATA_IMPORTS)
    publish_platform_legal_documents
    in_company { company.headquarters.update!(code: "MTZ") }
    host! "serraazul.painel.catalysthr.com.br"
  end

  after { travel_back }

  def in_company(&) = ActsAsTenant.with_tenant(company, &)

  def sign_in_hr
    accept_legal_documents(hr_user, brand)
    sign_in_with_mfa(hr_user.cpf, hr_user)
  end

  def confirm_password(return_to = "/imports")
    post "/confirm-password", params: { password: "Catalyst#2026", return_to: return_to }
  end

  def workbook(title, rows, filename: "planilha.xlsx")
    package = Axlsx::Package.new
    package.workbook.add_worksheet(name: title) { |sheet| rows.each { |row| sheet.add_row(row, types: Array.new(row.size, :string)) } }
    Rack::Test::UploadedFile.new(StringIO.new(package.to_stream.read), xlsx, original_filename: filename)
  end

  def send_file(kind, file)
    perform_enqueued_jobs(only: Imports::ValidateJob) { post "/imports", params: { kind: kind, file: file } }
    in_company { DataImport.order(:id).last }
  end

  def confirm(import, **params)
    perform_enqueued_jobs(only: Imports::ApplyJob) { patch "/imports/#{import.id}/confirm", params: params }
    import.reload
  end

  it "asks for the password before sending, confirming and downloading the errors (RN-18-041, D-663)" do
    sign_in_hr
    get "/imports"
    expect(response.body).to include("Colaboradores e vínculos", "Dependentes", "Dados bancários e PIX")

    get "/imports/new?kind=employees"
    expect(response).to redirect_to(%r{/confirm-password})
    post "/imports", params: { kind: "employees", file: workbook("Colaboradores", [ employee_headers ]) }
    expect(response).to redirect_to("/imports/new?kind=employees")
    expect(in_company { DataImport.count }).to eq(0)

    confirm_password
    import = send_file("employees", workbook("Colaboradores", [ employee_headers,
      [ "529.982.247-25", "Ana Lima", "10/05/1990", "1", "01/03/2026", "ANL", "MTZ", "2.500,00", "ana@example.com" ] ]))
    expect(import).to be_preview

    travel 6.minutes
    patch "/imports/#{import.id}/confirm"
    expect(response).to redirect_to(%r{/confirm-password})
    expect(import.reload).to be_preview
    get "/imports/#{import.id}/errors"
    expect(response).to redirect_to(%r{/confirm-password})

    confirm_password("/imports/#{import.id}")
    expect(confirm(import)).to be_completed
  end

  it "creates people without invitation nor eSocial, and reuses who already has an account (CA-18-004, RN-18-020, D-602)" do
    other_company = create(:company, name: "Padaria Pão Quente")
    elsewhere = register_employee(other_company, by: hr_user, position: create_position(other_company), name: "Rita Souza", cpf: "11144477735")
    sign_in_hr
    confirm_password
    import = send_file("employees", workbook("Colaboradores", [ employee_headers,
      [ "52998224725", "Ana Lima", "1990-05-10", "1", "2026-03-01", "anl", "mtz", "2.500,00", "ana@example.com", "", "", "", "Feminino", "12.345.678-9" ],
      [ "111.444.777-35", "Outro nome", "01/01/1980", "2", "01/04/2026", "ANL", "MTZ", "3000", "", "", "(54) 99999-0000" ] ]))
    expect([ import.valid_count, import.created_count, import.error_count ]).to eq([ 2, 2, 0 ])
    expect(in_company { WorkerProfile.count }).to eq(0)

    clear_enqueued_jobs
    import = confirm(import)
    expect(import).to be_completed
    expect(enqueued_jobs).to be_empty
    expect(ActionMailer::Base.deliveries).to be_empty

    in_company do
      ana = User.find_by!(cpf: "52998224725")
      profile = WorkerProfile.joins(:membership).find_by!(memberships: { user_id: ana.id })
      membership = profile.membership
      expect([ membership.status, membership.invitation_token_digest, membership.roles ]).to eq([ "invited", nil, %w[employee] ])
      expect([ profile.sex, profile.rg_number ]).to eq([ "female", "123456789" ])
      employment = profile.employments.sole
      expect([ employment.status, employment.registration_number, employment.revisions.sole.salary_cents ]).to eq([ "active", "1", 250_000 ])
      version = PaperTrail::Version.where(item: employment).order(:id).last
      expect([ version.request_id, version.whodunnit ]).to eq([ "import:#{import.id}", hr_user.id.to_s ])

      rita = User.find_by!(cpf: "11144477735")
      expect(rita.name).to eq("Rita Souza")
      expect(WorkerProfile.joins(:membership).find_by!(memberships: { user_id: rita.id }).personal_phone).to eq("54999990000")
    end
    expect(ActsAsTenant.with_tenant(other_company) { elsewhere.reload.personal_phone }).to be_nil

    get "/imports/#{import.id}"
    expect(response.body).to include("Próximo passo: liberar o acesso ao portal", "Convidar todos sem acesso")
  end

  it "updates the record's phone and keeps the e-mail of who exists (CA-18-003, D-663)" do
    profile = register_employee(company, by: hr_user, position: position, cpf: "52998224725", salary: "2.500,00")
    in_company { profile.update!(personal_email: "ana.pessoal@example.com", personal_phone: "54911112222") }
    number = in_company { profile.employments.sole.registration_number }
    login_phone = profile.user.mobile_phone
    sign_in_hr
    confirm_password
    import = send_file("employees", workbook("Colaboradores", [ employee_headers,
      [ "52998224725", "Ana Lima", "1990-05-10", number, "2026-03-01", "ANL", "MTZ", "", "", "54988887777", "54988887777", "" ] ]))
    expect([ import.updated_count, import.error_count ]).to eq([ 1, 0 ])

    get "/imports/#{import.id}"
    expect(response.body).to include("O que muda nos cadastros existentes", "Telefone pessoal", "54911112222", "54988887777")
    expect(response.body).not_to include("E-mail pessoal")

    confirm(import)
    in_company { profile.reload }
    expect([ profile.personal_phone, profile.personal_email ]).to eq([ "54988887777", "ana.pessoal@example.com" ])
    expect(profile.user.reload.mobile_phone).to eq(login_phone)
  end

  it "refuses a change of conditions, a registration of another person and codes that do not exist (D-207, D-663)" do
    profile = register_employee(company, by: hr_user, position: position, cpf: "52998224725", salary: "2.500,00")
    number = in_company { profile.employments.sole.registration_number }
    other = register_employee(company, by: hr_user, position: position, cpf: "86288366757", name: "Edu Reis")
    other_number = in_company { other.employments.sole.registration_number }
    sign_in_hr
    confirm_password
    import = send_file("employees", workbook("Colaboradores", [ employee_headers,
      [ "52998224725", "Ana Lima", "1990-05-10", number, "2026-03-01", "ANL", "MTZ", "3.100,00" ],
      [ "11144477735", "Bia Souza", "1990-05-10", other_number, "2026-03-01", "ANL", "MTZ", "2.500,00", "bia@example.com" ],
      [ "39053344705", "Caio Melo", "1990-05-10", "9", "2026-03-01", "XYZ", "MTZ", "2.500,00", "caio@example.com" ],
      [ "12345678900", "Dani Reis", "1990-05-10", "10", "2026-03-01", "ANL", "MTZ", "2.500,00", "dani@example.com" ],
      [ "39053344705", "Caio Melo", "1990-05-10", "11", "2026-12-01", "ANL", "MTZ", "2.500,00", "caio@example.com" ],
      [ "39053344705", "Caio Melo", "1990-05-10", "12", "2026-03-01", "ANL", "MTZ", "1.000,00", "caio@example.com" ],
      [ "11144477735", "Bia Souza", "1990-05-10", "9", "2026-03-01", "ANL", "MTZ", "2.500,00", "bia@example.com" ] ]))
    expect([ import.valid_count, import.error_count ]).to eq([ 0, 7 ])

    get "/imports/#{import.id}"
    body = response.body
    expect(body).to include("Salário é diferente do vínculo cadastrado", "Esta matrícula já é de outra pessoa na empresa.",
      "Nenhum cadastro com o código XYZ em Código do cargo.", "CPF: CPF inválido.", "quem ainda vai começar entra pela admissão",
      "fora da faixa do cargo", "Esta matrícula já aparece na linha 4 com outro CPF.")
    expect(body).to include(SensitiveData::MONEY_MASK)
    expect(body).not_to include("3.100,00")
  end

  it "imports dependents by the holder's CPF and the dependent's CPF or name (RN-04-043, D-663)" do
    profile = register_employee(company, by: hr_user, position: position, cpf: "52998224725")
    in_company { profile.dependents.create!(name: "Pedro Lima", birth_date: Date.new(2015, 4, 2), relationship_type: "child") }
    sign_in_hr
    confirm_password
    headers = [ "CPF do titular", "Nome do dependente", "Data de nascimento", "Parentesco", "CPF do dependente", "Dependente para o IRRF" ]
    import = send_file("dependents", workbook("Dependentes", [ headers,
      [ "52998224725", "pedro lima", "02/04/2015", "Filho(a)", "390.533.447-05", "Sim" ],
      [ "52998224725", "Lia Lima", "01/02/2018", "Filho(a)", "", "não" ],
      [ "11144477735", "Sem titular", "01/02/2018", "Filho(a)" ],
      [ "52998224725", "Lia Lima", "01/02/2018", "Filho(a)" ] ]))
    expect([ import.created_count, import.updated_count, import.error_count ]).to eq([ 1, 1, 2 ])

    get "/imports/#{import.id}"
    expect(response.body).to include("Nenhum colaborador com este CPF na empresa.", "Este dependente já aparece na linha 3.", "***.533.447-**")
    expect(response.body).not_to include("390.533.447-05", "39053344705")

    confirm_password("/imports/#{import.id}")
    confirm(import, only_valid: "1")
    in_company do
      pedro, lia = profile.dependents.order(:birth_date).to_a
      expect([ pedro.cpf, pedro.irrf, lia.irrf, profile.dependents.count ]).to eq([ "39053344705", true, false, 2 ])
    end
  end

  it "imports the primary account, ending the previous, with the declaration (CA-04-008, P-04-17, D-663)" do
    profile = register_employee(company, by: hr_user, position: position, cpf: "52998224725")
    old = in_company do
      BankAccounts::Register.call(profile: profile, attributes: { bank_code: "001", branch: "1234", account_number: "56789", account_type: "checking" },
        primary: true, by: hr_user)
    end
    sign_in_hr
    confirm_password
    headers = [ "CPF", "Código do banco", "Agência", "Conta", "Tipo de conta", "Tipo de chave PIX", "Chave PIX", "Principal" ]
    import = send_file("bank_accounts", workbook("Dados bancários", [ headers,
      [ "52998224725", "1", "1234", "56789", "conta corrente", "", "", "Não" ],
      [ "52998224725", "341", "0001", "99887-6", "Conta corrente" ],
      [ "52998224725", "", "", "", "", "e-mail", "Ana@Example.com", "não" ],
      [ "52998224725", "033", "1", "123", "conta poupança", "CPF", "52998224725", "Não" ] ]))
    expect([ import.created_count, import.unchanged_count, import.error_count ]).to eq([ 2, 1, 1 ])

    get "/imports/#{import.id}"
    expect(response.body).to include("Declaro que as contas e as chaves PIX estão no CPF de cada pessoa")
    expect(response.body).not_to include("998876")

    confirm_password("/imports/#{import.id}")
    patch "/imports/#{import.id}/confirm", params: { only_valid: "1" }
    expect(response).to redirect_to("/imports/#{import.id}")
    expect(import.reload).to be_preview

    import = confirm(import, only_valid: "1", declaration: "1")
    expect(import).to be_completed_with_errors
    in_company do
      expect(old.reload.status).to eq("ended")
      primary = profile.bank_accounts.active.find_by!(primary: true)
      expect([ primary.bank_code, primary.account_number, primary.declared_by ]).to eq([ "341", "998876", hr_user ])
      expect(profile.bank_accounts.active.where(primary: false).sole.pix_key).to eq("ana@example.com")
    end
  end

  it "gives the employees' template with the company's codes in the lists (D-662)" do
    sign_in_hr
    get "/imports/templates/employees"
    path = Rails.root.join("tmp/colaboradores-#{SecureRandom.hex(4)}.xlsx")
    File.binwrite(path, response.body)
    book = Roo::Excelx.new(path.to_s)
    expect(book.sheets).to eq(%w[Instruções Colaboradores Listas])
    expect(book.sheet("Colaboradores").row(1).first(5)).to eq([ "CPF", "Nome completo", "Data de nascimento", "Matrícula", "Data de admissão" ])
    expect(book.sheet("Listas").row(1)).to include("CLT", "ANL", "MTZ")
  ensure
    FileUtils.rm_f(path) if path
  end
end
