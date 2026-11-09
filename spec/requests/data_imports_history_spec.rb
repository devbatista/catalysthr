require "rails_helper"

# Spec 18, block 18c (D-661, D-664): the salary and position history, with the empty cells
# inherited from the revision before and the line on an existing date as a correction (D-603),
# and the departments' managers, only active ones, added without removing (RN-04-021).
RSpec.describe "Data imports of history and managers", type: :request do
  include ActiveJob::TestHelper

  let(:company) { create(:company, name: "Metalúrgica Serra Azul") }
  let(:brand) { create(:brand, owner: company, commercial_name: "Serra Azul RH") }
  let!(:hr_user) { enable_mfa(create(:user, name: "Juliana Ribeiro", cpf: "98765432100")) }
  let!(:hr) { create(:membership, user: hr_user, organization: company, roles: %w[hr_admin]) }
  let!(:analyst_position) { create_position(company, salary_min_cents: 100_000, salary_max_cents: 350_000).tap { |record| in_company { record.update!(code: "ANL") } } }
  let!(:lead_position) do
    create_position(company, name: "Supervisor", cbo_code: "414105", salary_min_cents: 300_000, salary_max_cents: 600_000)
      .tap { |record| in_company { record.update!(code: "SUP") } }
  end
  let(:xlsx) { "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet" }
  let(:history_headers) { [ "CPF", "Matrícula", "Vigente a partir de", "Motivo", "Código do cargo", "Salário", "Justificativa do salário fora da faixa" ] }

  before do
    travel_to Time.zone.local(2026, 11, 10, 10)
    brand.subdomains.create!(slug: "serraazul")
    Flipper.enable(FeatureFlags::SIGN_IN)
    Flipper.enable(FeatureFlags::DATA_IMPORTS)
    publish_platform_legal_documents
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

  def workbook(title, rows)
    package = Axlsx::Package.new
    package.workbook.add_worksheet(name: title) { |sheet| rows.each { |row| sheet.add_row(row, types: Array.new(row.size, :string)) } }
    Rack::Test::UploadedFile.new(StringIO.new(package.to_stream.read), xlsx, original_filename: "planilha.xlsx")
  end

  def send_file(kind, file)
    perform_enqueued_jobs(only: Imports::ValidateJob) { post "/imports", params: { kind: kind, file: file } }
    in_company { DataImport.order(:id).last }
  end

  def confirm(import, **params)
    perform_enqueued_jobs(only: Imports::ApplyJob) { patch "/imports/#{import.id}/confirm", params: params }
    import.reload
  end

  describe "the salary and position history" do
    let!(:profile) do
      register_employee(company, by: hr_user, position: analyst_position, cpf: "52998224725", salary: "2.500,00", started_on: Date.new(2018, 3, 1))
    end
    let(:number) { in_company { profile.employments.sole.registration_number } }

    it "corrects the admission's conditions, inherits the empty cells and is harmless when sent again (D-603, D-664)" do
      sign_in_hr
      confirm_password
      file = workbook("Histórico", [ history_headers,
        [ "529.982.247-25", number, "01/05/2024", "Promoção", "SUP", "4.000,00" ],
        [ "52998224725", number, "01/03/2018", "Alteração salarial", "", "1.500,00" ],
        [ "52998224725", number, "2022-05-01", "Alteração salarial", "", "2.500,00" ] ])
      import = send_file("employment_history", file)
      expect([ import.created_count, import.updated_count, import.error_count ]).to eq([ 2, 1, 0 ])
      expect(in_company { profile.employments.sole.revisions.count }).to eq(1)

      get "/imports/#{import.id}"
      expect(response.body).to include("As revisões com data passada são retroativas", "Motivo", "Admissão", "Correção", SensitiveData::MONEY_MASK)
      expect(response.body).not_to include("1.500,00")

      import = confirm(import)
      expect(import).to be_completed
      in_company do
        employment = profile.employments.sole.reload
        expect(employment.revisions.count).to eq(4)
        expect(employment.revision_on(Date.new(2019, 1, 1)).attributes.slice("salary_cents", "reason")).to eq("salary_cents" => 150_000, "reason" => "correction")
        expect(employment.revision_on(Date.new(2023, 1, 1)).attributes.slice("salary_cents", "position_id")).to eq("salary_cents" => 250_000, "position_id" => analyst_position.id)
        expect(employment.current_revision.attributes.slice("salary_cents", "position_id", "reason"))
          .to eq("salary_cents" => 400_000, "position_id" => lead_position.id, "reason" => "promotion")
        version = PaperTrail::Version.where(item_type: "EmploymentRevision").order(:id).last
        expect(version.request_id).to eq("import:#{import.id}")
      end

      again = send_file("employment_history", file)
      expect([ again.unchanged_count, again.valid_count, again.error_count ]).to eq([ 3, 0, 0 ])
    end

    it "refuses a date before the admission, a repeated date and an employment of someone else (RN-18-005)" do
      other = register_employee(company, by: hr_user, position: analyst_position, cpf: "86288366757", name: "Edu Reis")
      other_number = in_company { other.employments.sole.registration_number }
      sign_in_hr
      confirm_password
      import = send_file("employment_history", workbook("Histórico", [ history_headers,
        [ "52998224725", number, "01/01/2017", "Alteração salarial", "", "1.000,00" ],
        [ "52998224725", number, "01/06/2020", "Alteração salarial", "", "2.000,00" ],
        [ "52998224725", number, "01/06/2020", "Outro", "", "2.100,00" ],
        [ "52998224725", other_number, "01/06/2020", "Outro", "", "2.100,00" ],
        [ "52998224725", "999", "01/06/2020", "Outro", "", "2.100,00" ],
        [ "52998224725", number, "01/07/2020", "Promoção", "SUP", "2.000,00" ] ]))
      expect([ import.valid_count, import.error_count ]).to eq([ 1, 5 ])

      get "/imports/#{import.id}"
      expect(response.body).to include("Este vínculo já tem uma linha nesta data, na linha 3.", "Esta matrícula já é de outra pessoa na empresa.",
        "Nenhum vínculo com esta matrícula na empresa.", "fora da faixa do cargo")
    end

    it "asks for the password, as it carries salaries (RN-18-041)" do
      sign_in_hr
      get "/imports/new?kind=employment_history"
      expect(response).to redirect_to(%r{/confirm-password})
    end
  end

  describe "the departments' managers" do
    let!(:department) { in_company { Department.create!(name: "Produção", code: "PROD", unit: company.headquarters) } }
    let!(:manager_user) { create(:user, name: "Marcos Dias", cpf: "39053344705") }
    let!(:manager) { create(:membership, user: manager_user, organization: company, roles: %w[manager]) }
    let!(:other_manager) { create(:membership, user: create(:user, name: "Lia Rocha", cpf: "11144477735"), organization: company, roles: %w[manager]) }
    let(:headers) { [ "Código do departamento", "CPF do gestor", "Nome do gestor" ] }

    it "adds active managers without removing the others, and refuses who is not one yet (RN-04-021, D-664)" do
      in_company { department.department_managers.create!(membership: other_manager) }
      employee = register_employee(company, by: hr_user, position: analyst_position, cpf: "52998224725")
      sign_in_hr
      get "/imports/new?kind=department_managers"
      expect(response).to have_http_status(:ok)

      import = send_file("department_managers", workbook("Gestores", [ headers,
        [ "prod", "390.533.447-05", "Marcos Dias" ],
        [ "PROD", "11144477735", "Lia Rocha" ],
        [ "PROD", employee.user.cpf, "Ana Lima" ],
        [ "PROD", "86288366757", "Ninguém" ],
        [ "XYZ", "39053344705" ],
        [ "PROD", "39053344705" ] ]))
      expect([ import.created_count, import.unchanged_count, import.error_count ]).to eq([ 1, 1, 4 ])

      get "/imports/#{import.id}"
      expect(response.body).to include("Esta pessoa não é gestor ativo na empresa.", "Nenhuma pessoa com este CPF na empresa.",
        "Nenhum cadastro com o código XYZ", "já aparece como gestor deste departamento na linha 2.")

      confirm(import, only_valid: "1")
      expect(in_company { department.reload.managers.map(&:id) }).to contain_exactly(manager.id, other_manager.id)
    end
  end
end
