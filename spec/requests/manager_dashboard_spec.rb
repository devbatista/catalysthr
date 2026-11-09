require "rails_helper"

# Spec 17, block 17b (D-657, D-659): the manager's panel, only the team, with the same content
# as the portal's "Minha equipe" (RN-17-020, RN-17-021), each block in its own request.
RSpec.describe "Manager dashboard", type: :request do
  include ActiveJob::TestHelper

  let(:company) { create(:company, name: "Metalúrgica Serra Azul") }
  let(:brand) { create(:brand, owner: company, commercial_name: "Serra Azul RH") }
  let!(:hr_user) { enable_mfa(create(:user, name: "Juliana Ribeiro", cpf: "98765432100")) }
  let!(:hr) { create(:membership, user: hr_user, organization: company, roles: %w[hr_admin]) }
  let(:position) { create_position(company) }
  let(:manager_user) { enable_mfa(create(:user, name: "Carlos Mendes", cpf: "11144477735")) }
  let!(:manager) { create(:membership, user: manager_user, organization: company, roles: %w[manager]) }
  let(:caxias) { in_company { Unit.create!(name: "Caxias do Sul") } }
  let(:production) { in_company { Department.create!(name: "Produção", unit: company.headquarters).tap { |each| each.managers << manager } } }
  let(:caxias_production) { in_company { Department.create!(name: "Produção Caxias", unit: caxias).tap { |each| each.managers << manager } } }
  let(:sales) { in_company { Department.create!(name: "Vendas", unit: company.headquarters) } }
  let!(:ana) { register_employee(company, by: hr_user, position: position, name: "Ana Lima", department: production, cpf: "52998224725") }
  let!(:bruno) do
    register_employee(company, by: hr_user, position: position, name: "Bruno Reis", unit: caxias, department: caxias_production, cpf: "39053344705")
  end
  let!(:carla) { register_employee(company, by: hr_user, position: position, name: "Carla Dias", department: sales, cpf: "86288366757") }

  before do
    travel_to Time.zone.local(2026, 11, 10, 10)
    brand.subdomains.create!(slug: "serraazul")
    Flipper.enable(FeatureFlags::SIGN_IN)
    Flipper.enable(FeatureFlags::DASHBOARDS)
    publish_platform_legal_documents
    load_platform_document_types
    host! "serraazul.painel.catalysthr.com.br"
  end

  after { travel_back }

  def in_company(&) = ActsAsTenant.with_tenant(company, &)

  def sign_in(user)
    accept_legal_documents(user, brand)
    sign_in_with_mfa(user.cpf, user)
  end

  def block(name, **params)
    get "/dashboard/blocks/#{name}", params: params
    expect(response).to have_http_status(:ok)
    response.body
  end

  def pdf
    Rack::Test::UploadedFile.new(StringIO.new("%PDF-1.4\n%fake\n"), "application/pdf", original_filename: "doc.pdf")
  end

  def approved_cnh(profile, valid_until)
    in_company do
      form = Documents::Upload.new(worker_profile: profile, document_type: DocumentType.find_by!(code: "cnh"), files: [ pdf ], by: hr_user)
      raise form.errors.full_messages.to_sentence unless form.save

      form.version.files.blobs.each { |blob| blob.file_scan.record!(Antivirus::Clamd::Result.new(signature: nil)) }
      perform_enqueued_jobs(only: Documents::ConsolidatePdfJob)
      Documents::Review.new(form.version.reload, by: hr_user).approve(valid_until: valid_until)
      form.document.reload
    end
  end

  it "keeps the manager in the portal first, and opens the panel from there (RN-16-002, RN-17-021)" do
    sign_in(manager_user)
    get "/"
    expect(response).to redirect_to("/portal")
    get "/", params: { panel: "1" }
    expect(response.body).to include("Painel do gestor", "Terça-feira, 10 de novembro")
    urls = Nokogiri::HTML(response.body).css("[data-dashboard-block]").map { |node| node["data-dashboard-block"] }
    expect(urls).to eq(%w[/dashboard/blocks/team /dashboard/blocks/waiting /dashboard/blocks/team_expiring /dashboard/blocks/probations])
    expect(response.body).not_to include("Painel do RH", "Exportar")
  end

  it "shows only the team, active and on leave, without the reason (RN-17-020, D-190)" do
    in_company { bruno.employments.sole.update!(status: "on_leave") }
    sign_in(manager_user)
    team = block("team")
    expect(team).to include("Equipe · 2 pessoas", "1 afastada", "Ana Lima", "Bruno Reis", "Afastado", "Produção Caxias")
    expect(team).not_to include("Carla Dias")
  end

  it "shows what waits for the manager, the team's expirations as text and the experiences, as the portal (D-659)" do
    in_company do
      template = ProcessTemplate.create!(kind: "onboarding", name: "Integração")
      template.items.create!(position: 1, kind: "task", title: "Boas-vindas da equipe", responsible_role: "manager")
      template.update!(status: "active")
      Processes::Start.call(template: template.reload, employment: ana.employments.sole, started_by: hr_user, starter: hr,
        anchors: { "work_start" => Date.current + 3 })
    end
    cnh = approved_cnh(ana, Date.current + 10)
    approved_cnh(carla, Date.current + 10)
    dani = register_employee(company, by: hr_user, position: position, name: "Daniela Rocha", department: production, cpf: "71428793860",
      started_on: Date.new(2026, 10, 20))
    in_company do
      employment = dani.employments.sole
      employment.assign_experience(30, nil)
      employment.save!
    end
    sign_in(manager_user)

    expect(block("waiting")).to include("Esperando por você · 1", "Boas-vindas da equipe", "Ana Lima")
    expiring = block("team_expiring")
    expect(expiring).to include("CNH de Ana Lima vence em 20/11/2026", "Vencendo")
    expect(expiring).not_to include("Carla Dias", "/documents/#{cnh.id}")
    expect(block("probations")).to include("Daniela Rocha: termina em 18/11/2026. A decisão é do RH.")

    # The portal's "Minha equipe" shows the same (RN-17-021).
    get "/portal/team"
    expect(response.body).to include("Boas-vindas da equipe", "CNH de Ana Lima vence em 20/11/2026", "Daniela Rocha: termina em 18/11/2026")
  end

  it "filters by a unit of the team, and ignores one outside it (RN-17-004)" do
    sign_in(manager_user)
    get "/", params: { panel: "1" }
    expect(response.body).to include("Caxias do Sul", "Todas as unidades")
    team = block("team", unit_id: caxias.id)
    expect(team).to include("Bruno Reis")
    expect(team).not_to include("Ana Lima")
    other = in_company { Unit.create!(name: "Bento Gonçalves") }
    expect(block("team", unit_id: other.id)).to include("Ana Lima", "Bruno Reis")
  end

  it "gives the HR who is also a manager the HR's panel, and the manager's blocks only to managers" do
    in_company { manager.update!(roles: %w[manager hr_admin]) }
    sign_in(manager_user)
    get "/"
    expect(response.body).to include("Painel do RH")
    delete "/sign-out"

    sign_in(hr_user)
    get "/dashboard/blocks/team"
    expect(response).not_to have_http_status(:ok)
  end

  it "keeps the start page as it was while the flag is off (D-657)" do
    Flipper.disable(FeatureFlags::DASHBOARDS)
    sign_in(manager_user)
    get "/", params: { panel: "1" }
    expect(response.body).not_to include("Painel do gestor")
    get "/dashboard/blocks/team"
    expect(response).to have_http_status(:not_found)
  end
end
