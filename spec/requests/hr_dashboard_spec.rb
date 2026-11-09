require "rails_helper"

# Spec 17, block 17a (D-657, D-658): the HR panel, its blocks in their own requests, the lists
# the indicators open with the same numbers, the HR analyst's units, the client's filter, the
# recent activity and the contract's block.
RSpec.describe "HR dashboard", type: :request do
  include ActiveJob::TestHelper

  let(:company) { create(:company, name: "Metalúrgica Serra Azul") }
  let(:brand) { create(:brand, owner: company, commercial_name: "Serra Azul RH") }
  let!(:hr_user) { enable_mfa(create(:user, name: "Juliana Ribeiro", cpf: "98765432100")) }
  let!(:hr) { create(:membership, user: hr_user, organization: company, roles: %w[hr_admin]) }
  let(:position) { create_position(company) }
  let(:caxias) { in_company { Unit.create!(name: "Caxias do Sul") } }
  let(:bento) { in_company { Unit.create!(name: "Bento Gonçalves") } }
  let!(:ana) { register_employee(company, by: hr_user, position: position, name: "Ana Lima", unit: caxias, cpf: "52998224725") }
  let!(:bruno) { register_employee(company, by: hr_user, position: position, name: "Bruno Reis", unit: bento, cpf: "39053344705") }

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

  def sign_in_hr(user = hr_user)
    accept_legal_documents(user, brand)
    sign_in_with_mfa(user.cpf, user)
  end

  def pdf
    Rack::Test::UploadedFile.new(StringIO.new("%PDF-1.4\n%fake\n"), "application/pdf", original_filename: "doc.pdf")
  end

  # A version of the type for the person, through the virus scan, waiting for the review.
  def send_document(profile, code, by: hr_user)
    in_company do
      form = Documents::Upload.new(worker_profile: profile, document_type: DocumentType.find_by!(code: code), files: [ pdf ], by: by)
      raise form.errors.full_messages.to_sentence unless form.save

      form.version.files.blobs.each { |blob| blob.file_scan.record!(Antivirus::Clamd::Result.new(signature: nil)) }
      perform_enqueued_jobs(only: Documents::ConsolidatePdfJob)
      form.version.reload
    end
  end

  def approve(version, valid_until: nil)
    in_company { Documents::Review.new(version, by: hr_user).approve(valid_until: valid_until) }
  end

  def block(name, **params)
    get "/dashboard/blocks/#{name}", params: params
    expect(response).to have_http_status(:ok)
    response.body
  end

  def indicator(body, key)
    Nokogiri::HTML(body).at_css("[data-indicator='#{key}'] [data-indicator-value]")&.text&.strip
  end

  def analyst_of(unit, modules: %w[admissao documentos])
    user = enable_mfa(create(:user, name: "Paula Souza", cpf: "86288366757"))
    membership = create(:membership, user: user, organization: company, roles: %w[hr_analyst], enabled_modules: modules)
    in_company { MembershipUnit.create!(membership: membership, unit: unit) }
    user
  end

  # An onboarding process of the person with one task already past its date.
  def overdue_task(profile, title:)
    in_company do
      template = ProcessTemplate.create!(kind: "onboarding", name: "Integração #{title}")
      template.items.create!(position: 1, kind: "task", title: title, responsible_role: "hr", due_offset_days: 0,
        due_anchor: "work_start")
      template.update!(status: "active")
      instance = Processes::Start.call(template: template, employment: profile.employments.sole, started_by: hr_user, starter: hr,
        anchors: { "work_start" => Date.current })
      instance.items.each { |item| item.update!(due_on: Date.current - 2) }
      instance
    end
  end

  describe "the page and the flag (D-657)" do
    it "keeps the start page as it was while the flag is off, and the blocks answer 404" do
      Flipper.disable(FeatureFlags::DASHBOARDS)
      sign_in_hr
      get "/"
      expect(response.body).to include("Olá, Juliana.")
      expect(response.body).not_to include("Painel do RH")
      get "/dashboard/blocks/indicators"
      expect(response).to have_http_status(:not_found)
      get "/documents/pending"
      expect(response).to have_http_status(:not_found)
    end

    it "frames the blocks, each in its own request, without the numbers in the page (RN-17-090, CA-17-012)" do
      sign_in_hr
      get "/"
      expect(response.body).to include("Painel do RH", "Terça-feira, 10 de novembro", "Caxias do Sul", "Bento Gonçalves")
      urls = Nokogiri::HTML(response.body).css("[data-dashboard-block]").map { |node| node["data-dashboard-block"] }
      expect(urls).to eq(%w[/dashboard/blocks/indicators /dashboard/blocks/pending_by_unit /dashboard/blocks/upcoming
        /dashboard/blocks/activity])
      expect(response.body).not_to include("data-indicator=")
      # Without the export, which comes in phase 5, and without the modules still to build.
      expect(response.body).not_to include("Exportar", "Resumo operacional", "Aprovações aguardando", "/dashboard/blocks/usage")

      expect(block("activity")).to include("Atividade recente")
      expect(block("indicators")).to include("Colaboradores ativos")
      get "/dashboard/blocks/other"
      expect(response).to have_http_status(:not_found)
    end

    it "keeps each block 60 seconds, and Atualizar makes it again (RN-17-091)" do
      allow(Rails).to receive(:cache).and_return(ActiveSupport::Cache::MemoryStore.new)
      sign_in_hr
      block("indicators")
      first = response.headers["X-Generated-At"]
      expect(indicator(response.body, "employees")).to eq("2")

      register_employee(company, by: hr_user, position: position, name: "Carla Dias", unit: caxias, cpf: "11144477735")
      travel 30.seconds
      expect(indicator(block("indicators"), "employees")).to eq("2")
      expect(response.headers["X-Generated-At"]).to eq(first)
      expect(response.headers["Cache-Control"]).to eq("no-store")

      expect(indicator(block("indicators", refresh: "1"), "employees")).to eq("3")
      expect(response.headers["X-Generated-At"].to_i).to eq(first.to_i + 30)
      # Another filter is another entry.
      expect(indicator(block("indicators", unit_id: caxias.id), "employees")).to eq("2")
    end

    it "is not for the manager nor the employee" do
      user = enable_mfa(create(:user, name: "Carlos Mendes", cpf: "11144477735"))
      create(:membership, user: user, organization: company, roles: %w[manager])
      sign_in_hr(user)
      get "/", params: { panel: "1" }
      expect(response.body).not_to include("Painel do RH")
      get "/dashboard/blocks/indicators"
      expect(response).not_to have_http_status(:ok)
    end
  end

  describe "the indicators and their lists (RN-17-002, P-17-01)" do
    it "opens the pending documents with the same number (CA-17-001, D-658)" do
      send_document(ana, "rg")
      send_document(bruno, "cpf")
      sign_in_hr
      school = in_company { DocumentType.find_by!(code: "school_statement") }
      post "/document-requests", params: { request: { document_type_id: school.id, due_on: "2026-11-20" },
        audience: { unit_ids: [ caxias.id, bento.id ] } }
      expect(in_company { DocumentRequestTarget.pending.count }).to eq(2)
      # Past its date: the form only takes a future one.
      in_company { DocumentRequest.sole.update_columns(due_on: Date.new(2026, 11, 5)) }

      body = block("indicators")
      expect(indicator(body, "documents")).to eq("4")
      expect(body).to include("2 pedidos vencidos")

      get "/documents/pending"
      expect(response.body).to include("4 documentos aguardando revisão ou envio.", "Aguardando revisão · 2", "Pedidos não atendidos · 2",
        "Ana Lima", "Bruno Reis")
      get "/documents/pending", params: { tab: "requests" }
      expect(response.body).to include("2 pedidos passaram do prazo.", "05/11/2026")

      expect(indicator(block("indicators", unit_id: caxias.id), "documents")).to eq("2")
      get "/documents/pending", params: { unit_id: caxias.id }
      expect(response.body).to include("2 documentos aguardando revisão ou envio.", "Caxias do Sul", "Ver tudo")
      expect(response.body).not_to include("Bruno Reis")
    end

    it "opens the overdue items, by unit (RN-06-028, D-658)" do
      overdue_task(ana, title: "Entregar o crachá")
      overdue_task(bruno, title: "Treinar na máquina")
      sign_in_hr

      body = block("indicators")
      expect(indicator(body, "overdue")).to eq("2")
      get "/overdue-items"
      expect(response.body).to include("2 tarefas atrasadas", "Entregar o crachá", "Treinar na máquina", "08/11/2026")

      pending = block("pending_by_unit")
      expect(pending).to include("Pendências por unidade", "Caxias do Sul", "Bento Gonçalves", "/overdue-items?unit_id=#{caxias.id}")
      get "/overdue-items", params: { unit_id: bento.id }
      expect(response.body).to include("1 tarefa atrasada", "Treinar na máquina")
      expect(response.body).not_to include("Entregar o crachá")
    end

    it "opens the expirations of the 30 days, without the expired ones (D-658)" do
      approve(send_document(ana, "cnh"), valid_until: Date.new(2026, 11, 20))
      approve(send_document(bruno, "cnh"), valid_until: Date.new(2026, 11, 5))
      approve(send_document(bruno, "rg"))
      carla = register_employee(company, by: hr_user, position: position, name: "Carla Dias", unit: caxias, cpf: "11144477735",
        started_on: Date.new(2026, 11, 1))
      in_company do
        employment = carla.employments.sole
        employment.assign_experience(30, nil)
        employment.save!
        expect(employment.experience_ends_on).to eq(Date.new(2026, 11, 30))
      end
      sign_in_hr

      body = block("indicators")
      expect(indicator(body, "expirations")).to eq("2")
      upcoming = block("upcoming")
      expect(upcoming).to include("CNH · Ana Lima", "20/11", "Fim da experiência · Carla Dias", "30/11")
      expect(upcoming).not_to include("Bruno Reis")

      get "/upcoming-expirations"
      expect(response.body).to include("2 vencimentos", "CNH", "Fim da experiência", "em 10 dias", "Ver os documentos já vencidos")
      expect(response.body).not_to include("Bruno Reis")
    end

    it "opens the people active or on leave (RN-17-010)" do
      in_company { bruno.employments.sole.update!(status: "on_leave") }
      sign_in_hr
      body = block("indicators")
      expect(indicator(body, "employees")).to eq("2")
      get "/employees", params: { situation: "active" }
      expect(response.body).to include("Ativos e afastados", "Todos · 2")
      get "/employees", params: { situation: "active", unit_id: bento.id }
      expect(response.body).to include("Bruno Reis")
      expect(response.body).not_to include("Ana Lima")
    end
  end

  describe "the HR analyst's scope (RN-17-001, RN-17-014)" do
    it "counts only the analyst's units (CA-17-002)" do
      send_document(ana, "rg")
      send_document(bruno, "cpf")
      overdue_task(bruno, title: "Treinar na máquina")
      sign_in_hr(analyst_of(caxias))

      get "/"
      expect(response.body).to include("Painel do RH")
      expect(response.body).not_to include("Bento Gonçalves")
      body = block("indicators")
      expect(indicator(body, "documents")).to eq("1")
      expect(indicator(body, "employees")).to eq("1")
      expect(block("pending_by_unit")).not_to include("Bento Gonçalves")

      # A unit outside the scope is ignored, never opened.
      expect(indicator(block("indicators", unit_id: bento.id), "documents")).to eq("1")
      get "/documents/pending", params: { unit_id: bento.id }
      expect(response.body).not_to include("Bruno Reis")
      get "/overdue-items"
      expect(response.body).not_to include("Treinar na máquina")
    end

    it "hides the indicators of the modules not released to the analyst (RN-17-014)" do
      send_document(ana, "rg")
      sign_in_hr(analyst_of(caxias, modules: []))
      body = block("indicators")
      expect(indicator(body, "documents")).to be_nil
      expect(indicator(body, "admissions")).to be_nil
      expect(indicator(body, "employees")).to eq("1")
      get "/documents/pending"
      expect(response).to have_http_status(:found).or have_http_status(:forbidden)
    end
  end

  describe "the client's filter (RN-17-005, P-17-25)" do
    it "filters by client and by people without one" do
      client = in_company do
        company.update!(uses_allocation_clients: true)
        AllocationClient.create!(name: "Vinícola Aurora")
      end
      in_company do
        revision = ana.employments.sole.effective_revision
        revision.update_columns(allocation_client_id: client.id)
      end
      sign_in_hr
      get "/"
      expect(response.body).to include("Vinícola Aurora", "Sem cliente")

      expect(indicator(block("indicators", client_id: client.id), "employees")).to eq("1")
      expect(indicator(block("indicators", client_id: "none"), "employees")).to eq("1")
      get "/employees", params: { situation: "active", client_id: "none" }
      expect(response.body).to include("Bruno Reis")
      expect(response.body).not_to include("Ana Lima")
    end
  end

  describe "the recent activity (RN-17-011, P-17-03, D-658)" do
    it "writes the documents sent, without the type's name for health, in the scope" do
      send_document(ana, "rg")
      send_document(bruno, "aso_periodic")
      in_company do
        expect(ActivityEvent.order(:occurred_at).pluck(:text)).to eq([ "Juliana Ribeiro enviou RG de Ana Lima",
          "Juliana Ribeiro enviou um documento de Bruno Reis" ])
        expect(ActivityEvent.find_by(unit_id: bento.id).url).to eq("/employees/#{bruno.id}/documents?category=health")
      end

      sign_in_hr
      expect(block("activity")).to include("Juliana Ribeiro enviou RG de Ana Lima", "Juliana Ribeiro enviou um documento de Bruno Reis", "10:00")
      expect(block("activity", unit_id: caxias.id)).not_to include("Bruno Reis")

      delete "/sign-out"
      sign_in_hr(analyst_of(bento))
      activity = block("activity")
      expect(activity).to include("enviou um documento de Bruno Reis")
      expect(activity).not_to include("Ana Lima")
    end

    it "writes nothing in an impersonate's simulation (RN-02-085)" do
      in_company { Simulation.run { ActivityEvent.record("document_sent", employment: ana.employments.sole, module_code: "documentos", text: "x") } }
      expect(in_company { ActivityEvent.count }).to eq(0)
    end

    it "deletes the lines older than 90 days (D-657)" do
      in_company do
        ActivityEvent.create!(kind: "document_sent", module_code: "documentos", text: "Antigo", occurred_at: 91.days.ago)
        ActivityEvent.create!(kind: "document_sent", module_code: "documentos", text: "Recente", occurred_at: 89.days.ago)
      end
      Dashboards::PurgeActivityJob.perform_now
      Dashboards::PurgeActivityJob.perform_now
      expect(in_company { ActivityEvent.pluck(:text) }).to eq([ "Recente" ])
    end
  end

  describe "the contract (RN-17-030, RN-17-031, P-17-06)" do
    before { Flipper.enable(FeatureFlags::BILLING) }

    it "shows the direct company's plan, status and month to the HR administrator" do
      subscription = contract_for(company, status: "trialing")
      UsagePeriod.create!(billing_account: subscription.billing_account, company: company, period: "2026-11", peak_employees: 2)
      sign_in_hr
      get "/"
      expect(response.body).to include("/dashboard/blocks/usage")
      usage = block("usage")
      expect(usage).to include("Contrato", subscription.plan_version.plan.name, "Em teste", "2 no pico do mês", "Ver as faturas")
    end

    it "shows only the own usage in a partner's company, never the partner's contract" do
      partner = create(:partner)
      partner_company = create(:company, partner: partner, name: "Padaria Pão Quente")
      partner_brand = create(:brand, owner: partner, commercial_name: "Aurora RH")
      partner_brand.subdomains.create!(slug: "aurora")
      subscription = contract_for(partner)
      UsagePeriod.create!(billing_account: subscription.billing_account, company: partner_company, period: "2026-11", peak_employees: 7)
      user = enable_mfa(create(:user, name: "Rita Prado", cpf: "11144477735"))
      create(:membership, user: user, organization: partner_company, roles: %w[hr_admin])
      host! "aurora.painel.catalysthr.com.br"
      accept_legal_documents(user, partner_brand)
      sign_in_with_mfa(user.cpf, user)
      post "/current-company", params: { company_id: partner_company.id }

      usage = block("usage")
      expect(usage).to include("Consumo da empresa", "7 no pico do mês")
      expect(usage).not_to include("Plano", "Situação", subscription.plan_version.plan.name, "faturas")
    end

    it "is not for the HR analyst" do
      contract_for(company)
      sign_in_hr(analyst_of(caxias))
      get "/"
      expect(response.body).not_to include("/dashboard/blocks/usage")
      get "/dashboard/blocks/usage"
      expect(response).to have_http_status(:not_found)
    end
  end
end
