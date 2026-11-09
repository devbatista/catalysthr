require "rails_helper"

# Spec 17, block 17c (D-657, D-660): the partner's consolidated view on the partner's start
# page, numbers by company and never people (RN-17-040 to RN-17-042, CA-17-005), and the date
# the portal was opened as the installed app (RN-17-041).
RSpec.describe "Partner overview", type: :request do
  include ActiveJob::TestHelper

  let(:partner) { create(:partner, name: "Aurora Gestão de Pessoas") }
  let(:brand) { create(:brand, owner: partner, commercial_name: "Aurora RH") }
  let!(:padaria) { create(:company, partner: partner, name: "Padaria Pão Quente") }
  let!(:transportes) { create(:company, partner: partner, name: "Transportes Rápidos") }
  let!(:outsider) { create(:company, :with_partner, name: "Cliente de Outro Parceiro") }
  let!(:admin) { enable_mfa(create(:user, name: "Paula Admin", cpf: "98765432100")) }
  let(:hr_user) { create(:user, name: "Juliana Ribeiro", cpf: "86288366757") }
  let!(:hr) { create(:membership, user: hr_user, organization: padaria, roles: %w[hr_admin]) }
  let(:position) { create_position(padaria) }
  let!(:ana) { register_employee(padaria, by: hr_user, position: position, name: "Ana Lima", cpf: "52998224725") }
  let!(:bruno) { register_employee(padaria, by: hr_user, position: position, name: "Bruno Reis", cpf: "39053344705") }

  before do
    travel_to Time.zone.local(2026, 11, 10, 10)
    create(:membership, user: admin, organization: partner, roles: %w[partner_admin])
    brand.subdomains.create!(slug: "aurora")
    Flipper.enable(FeatureFlags::SIGN_IN)
    Flipper.enable(FeatureFlags::DASHBOARDS)
    Flipper.enable(FeatureFlags::ADMISSIONS)
    publish_platform_legal_documents
    load_platform_document_types
    host! "aurora.painel.catalysthr.com.br"
  end

  after { travel_back }

  def in_padaria(&) = ActsAsTenant.with_tenant(padaria, &)

  def sign_in_as(user)
    accept_legal_documents(user, brand)
    sign_in_with_mfa(user.cpf, user)
  end

  def block(name)
    get "/partner/overview/#{name}"
    expect(response).to have_http_status(:ok)
    response.body
  end

  def row(body, kind, company)
    Nokogiri::HTML(body).at_css("[data-#{kind}-company='#{company.id}']")
  end

  # An admission whose process had no event since the date.
  def stopped_admission(since:, cpf:)
    in_padaria do
      ProcessTemplate.admission.active.first || ProcessTemplate.create!(kind: "admission", name: "Admissão padrão").tap do |model|
        model.items.create!(position: 1, kind: "task", title: "Conferir dados", responsible_role: "hr")
        model.update!(status: "active")
        model.make_default!
      end
      registration = AdmissionRegistration.new(name: "Pessoa #{cpf}", cpf: cpf, email: "#{cpf}@example.com", kind: "clt",
        category: "standard", started_on: Date.current + 20, position_id: position.id, unit_id: padaria.headquarters.id,
        department_id: Department.find_or_create_by!(name: "Produção", unit: padaria.headquarters).id)
      raise registration.errors.full_messages.to_sentence unless registration.save(company: padaria.reload, by: hr_user, starter: hr)

      instance = registration.admission.process_instance
      instance.update_columns(created_at: since)
      instance.events.update_all(created_at: since)
      registration.admission
    end
  end

  def overdue_item
    in_padaria do
      template = ProcessTemplate.create!(kind: "onboarding", name: "Integração")
      template.items.create!(position: 1, kind: "task", title: "Entregar o crachá", responsible_role: "hr")
      template.update!(status: "active")
      instance = Processes::Start.call(template: template, employment: ana.employments.sole, started_by: hr_user, starter: hr,
        anchors: { "work_start" => Date.current })
      instance.items.each { |item| item.update!(due_on: Date.current - 1) }
    end
  end

  def late_request
    in_padaria do
      ability = Ability.new(hr_user, area: :panel, brand: brand, company: padaria)
      form = Documents::RequestForm.new(document_type: DocumentType.find_by!(code: "school_statement"), due_on: Date.current + 5,
        audience_filter: { "unit_ids" => [ padaria.headquarters.id ] }, by: hr_user, ability: ability)
      raise form.errors.full_messages.to_sentence unless form.save

      DocumentRequest.sole.update_columns(due_on: Date.current - 2)
    end
  end

  it "puts the consolidated view on the start page, with the portfolio below, only while the flag is on (D-660)" do
    sign_in_as(admin)
    get "/partner"
    urls = Nokogiri::HTML(response.body).css("[data-dashboard-block]").map { |node| node["data-dashboard-block"] }
    expect(urls).to eq(%w[/partner/overview/portfolio /partner/overview/health /partner/overview/adoption])
    expect(response.body).to include("Empresas da carteira", "Padaria Pão Quente")

    Flipper.disable(FeatureFlags::DASHBOARDS)
    get "/partner"
    expect(response.body).not_to include("data-dashboard-block", "Empresas da carteira")
    get "/partner/overview/health"
    expect(response).to have_http_status(:not_found)
  end

  it "shows numbers by company, never a person nor a list (CA-17-005)" do
    stopped_admission(since: 8.days.ago, cpf: "11144477735")
    overdue_item
    late_request
    sign_in_as(admin)

    portfolio = block("portfolio")
    expect(portfolio).to include("Carteira e consumo", "Padaria Pão Quente", "Transportes Rápidos")
    expect(portfolio).not_to include("Cliente de Outro Parceiro")

    health = block("health")
    padaria_row = row(health, "health", padaria)
    expect(padaria_row["data-signal"]).to eq("red")
    expect(padaria_row.text).to include("Vermelho", "1 há mais de 7 dias")
    expect(row(health, "health", transportes)["data-signal"]).to eq("green")

    [ portfolio, health, block("adoption") ].each do |body|
      expect(body).not_to include("Ana Lima", "Bruno Reis", "Pessoa 11144477735", "Entregar o crachá")
      expect(Nokogiri::HTML(body).css("a")).to be_empty
    end
  end

  it "makes the signal yellow with anything late and red only after 7 days (RN-17-042, D-660)" do
    sign_in_as(admin)
    stopped_admission(since: 4.days.ago, cpf: "11144477735")
    expect(row(block("health"), "health", padaria)["data-signal"]).to eq("yellow")

    in_padaria { Admission.find_each { |admission| admission.process_instance.update!(status: "cancelled", cancel_reason: "Teste") } }
    late_request
    get "/partner/overview/health", params: { refresh: "1" }
    expect(row(response.body, "health", padaria)["data-signal"]).to eq("yellow")
    expect(row(response.body, "health", padaria).text.squish).to include("Documentos 3 · pedidos vencidos 3 · itens atrasados 0")
  end

  it "counts the adoption: the portal in 30 days and the app or the push (RN-17-041)" do
    UserSession.create!(user: ana.user, token_digest: SecureRandom.hex, area: "panel", last_seen_at: 2.days.ago, expires_at: 1.day.from_now)
    UserSession.create!(user: bruno.user, token_digest: SecureRandom.hex, area: "panel", last_seen_at: 40.days.ago, expires_at: 1.day.ago)
    ana.user.update_column(:app_opened_at, 3.days.ago)
    sign_in_as(admin)

    adoption = row(block("adoption"), "adoption", padaria).text
    expect(adoption).to include("2", "50%")
    expect(row(block("adoption"), "adoption", transportes).text).to include("—")
  end

  it "gives the consultant only the assigned companies (RN-17-040)" do
    user = enable_mfa(create(:user, name: "Caio Consultor", cpf: "11144477735"))
    consultant = create(:membership, user: user, organization: partner, roles: %w[consultant])
    consultant.partner_membership_companies.create!(company: transportes)
    sign_in_as(user)

    health = block("health")
    expect(health).to include("Transportes Rápidos")
    expect(health).not_to include("Padaria Pão Quente")
    expect(block("portfolio")).not_to include("faixa")
  end

  describe "the installed app's opening (RN-17-041, D-657)" do
    def sign_in_employee(profile)
      profile.user.update!(password: "Catalyst#2026", password_confirmation: "Catalyst#2026")
      in_padaria { profile.membership.update!(status: "active") }
      accept_legal_documents(profile.user, brand)
      post "/sign-in", params: { user: { login: profile.user.cpf, password: "Catalyst#2026" } }
    end

    it "keeps only the date, once a day, with no change in the trail" do
      sign_in_employee(ana)
      get "/portal"
      expect(response.body).to include("data-app-opened=\"/portal/app-opened\"")

      expect { post "/portal/app-opened" }.not_to change(PaperTrail::Version, :count)
      expect(response).to have_http_status(:no_content)
      expect(ana.user.reload.app_opened_at).to eq(Time.current)

      travel 2.hours
      post "/portal/app-opened"
      expect(ana.user.reload.app_opened_at).to eq(2.hours.ago)
    end
  end
end
