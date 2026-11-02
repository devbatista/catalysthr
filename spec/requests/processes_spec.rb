require "rails_helper"

# Spec 06, block 06c (RN-06-050 to RN-06-066, D-641): the page of a process under way, for
# the HR, the manager and the client manager (spec 03, sections 4.4 and 4.12).
RSpec.describe "Processes under way", type: :request do
  include ActiveJob::TestHelper

  let(:partner) { create(:partner) }
  let(:partner_brand) { create(:brand, owner: partner, commercial_name: "Aurora RH") }
  let(:company) { create(:company, partner: partner, name: "Padaria Pão Quente") }
  let(:hr_user) { create(:user, name: "Juliana Ribeiro") }
  let!(:hr) { create(:membership, user: hr_user, organization: company, roles: %w[hr_admin]) }
  let(:manager_user) { create(:user, name: "Carlos Mendes", cpf: "11144477735") }
  let!(:manager) { create(:membership, user: manager_user, organization: company, roles: %w[manager]) }
  let(:position) { create_position(company) }
  let(:department) { in_company { Department.create!(name: "Produção", unit: company.headquarters).tap { |each| each.managers << manager } } }
  let(:profile) { register_employee(company, by: hr_user, position: position, name: "Ana Souza", department: department) }
  let(:template) { in_company { ProcessTemplate.create!(kind: "onboarding", name: "Integração padrão") } }
  let(:instance) do
    in_company do
      check = template.items.create!(position: 1, kind: "task", title: "Conferir documentos", responsible_role: "hr")
      template.items.create!(position: 2, kind: "task", title: "Apresentar a equipe", responsible_role: "manager")
      template.items.create!(position: 3, kind: "approval", title: "Aprovação do gestor", responsible_role: "manager")
      template.items.create!(position: 4, kind: "forward", title: "Encaminhar à contabilidade", responsible_role: "hr",
        config: { "record" => true }, depends_on_item_ids: [ check.id ])
      template.update!(status: "active")
      Processes::Start.call(template: template, employment: profile.employments.sole, started_by: hr_user, starter: hr,
        anchors: { "work_start" => Date.current + 7 })
    end
  end

  before do
    Flipper.enable(FeatureFlags::SIGN_IN)
    publish_platform_legal_documents
    partner_brand.subdomains.create!(slug: "aurora")
    host! "aurora.painel.catalysthr.com.br"
  end

  def in_company(&)
    ActsAsTenant.with_tenant(company, &)
  end

  def sign_in_member(membership)
    user = enable_mfa(membership.user)
    accept_legal_documents(user, partner_brand)
    sign_in_with_mfa(user.cpf, user)
    post "/current-company", params: { company_id: company.id }
  end

  def items
    in_company { instance.items.reload.index_by(&:title) }
  end

  describe "for the HR administrator" do
    before do
      hr_user.update!(cpf: "52998224725")
      instance
      sign_in_member(hr)
    end

    it "shows every item, the blocked one and the history (RN-06-051)" do
      get "/processes/#{instance.id}"

      expect(response.body).to include("Integração de Ana Souza", "Conferir documentos", "Apresentar a equipe", "Carlos Mendes",
        "Bloqueado", "Aguardando: Conferir documentos", "Histórico", "Processo iniciado a partir do modelo Integração padrão")
    end

    it "frees the forward after the check, records it with a receipt and ends the process on confirmation (RN-06-066, RN-06-053)" do
      patch "/processes/#{instance.id}/items/#{items["Conferir documentos"].id}/done", params: { comment: "Tudo certo" }
      expect(flash[:notice]).to eq("Item concluído.")
      perform_enqueued_jobs(only: Processes::UnblockItemsJob)
      expect(items["Encaminhar à contabilidade"]).to be_pending

      forward = items["Encaminhar à contabilidade"]
      receipt = Rack::Test::UploadedFile.new(StringIO.new("%PDF-1.4 protocolo"), "application/pdf", original_filename: "protocolo.pdf")
      patch "/processes/#{instance.id}/items/#{forward.id}/forward", params: { sent_on: Date.current.iso8601, receipt: receipt }
      expect(forward.reload).to have_attributes(status: "done", result: { "sent_on" => Date.current.iso8601 })
      expect(FileScan.find_by!(blob: forward.forward_receipt.blob)).to be_scanning
      get "/processes/#{instance.id}/items/#{forward.id}/receipt"
      expect(response).to have_http_status(:not_found)

      patch "/processes/#{instance.id}/complete"
      expect(flash[:alert]).to eq("Ainda há itens obrigatórios em aberto.")

      patch "/processes/#{instance.id}/items/#{items["Apresentar a equipe"].id}/skip", params: { skipped_reason: "Equipe de férias" }
      patch "/processes/#{instance.id}/items/#{items["Aprovação do gestor"].id}/approve"
      get "/processes/#{instance.id}"
      expect(response.body).to include("Pronto para concluir", "Dispensado: Equipe de férias", "Comentário: Tudo certo")

      patch "/processes/#{instance.id}/complete"
      expect(instance.reload).to have_attributes(status: "completed", completed_by: hr_user)
    end

    it "refuses a receipt that is not PDF, JPG or PNG" do
      forward = items["Encaminhar à contabilidade"]
      forward.update!(status: "pending")
      receipt = Rack::Test::UploadedFile.new(StringIO.new("MZ"), "application/pdf", original_filename: "protocolo.pdf")

      patch "/processes/#{instance.id}/items/#{forward.id}/forward", params: { sent_on: Date.current.iso8601, receipt: receipt }

      expect(flash[:alert]).to eq("O comprovante precisa ser PDF, JPG ou PNG")
      expect(forward.reload).to be_pending
    end

    it "adds, changes the people and the date, moves and removes items, each in the history (RN-06-051, RN-06-021)" do
      post "/processes/#{instance.id}/items", params: { item: { kind: "task", title: "Entregar uniforme", responsible_role: "manager",
        due_on: (Date.current + 3).iso8601, required: "1" } }
      added = items["Entregar uniforme"]
      expect(added).to have_attributes(responsible_membership_ids: [ manager.id ], due_manually_set: true, position: 5)

      get "/processes/#{instance.id}/items/#{added.id}/edit"
      expect(response.body).to include("Carlos Mendes (Gestor)", "Juliana Ribeiro (RH administrador)")
      patch "/processes/#{instance.id}/items/#{added.id}", params: { item: { title: "Entregar uniforme e EPI",
        responsible_membership_ids: [ "", hr.id ], due_on: "" } }
      expect(added.reload).to have_attributes(title: "Entregar uniforme e EPI", responsible_membership_ids: [ hr.id ], due_on: nil)

      patch "/processes/#{instance.id}/items/#{added.id}/move", params: { direction: "up" }
      delete "/processes/#{instance.id}/items/#{items["Apresentar a equipe"].id}"

      expect(in_company { instance.events.pluck(:action) }).to include("item_added", "responsible_changed", "item_updated",
        "item_moved", "item_removed")
      get "/processes/#{instance.id}"
      expect(response.body).to include(CGI.escapeHTML("\"Apresentar a equipe\" removido"),
        CGI.escapeHTML("\"Entregar uniforme e EPI\" alterado: título, prazo"))
    end

    it "cancels with a reason" do
      patch "/processes/#{instance.id}/cancel", params: { cancel_reason: "" }
      expect(flash[:alert]).to eq("Informe o motivo do cancelamento.")

      patch "/processes/#{instance.id}/cancel", params: { cancel_reason: "Candidato desistiu" }
      expect(instance.reload).to have_attributes(status: "cancelled", cancel_reason: "Candidato desistiu")
      post "/processes/#{instance.id}/items", params: { item: { kind: "task", title: "Depois", responsible_role: "hr" } }
      expect(flash[:alert]).to eq("Este item ou processo não pode mais ser alterado.")
    end

    it "answers 404 for another company's process (RN-01-013)" do
      other = create(:company, partner: partner)
      other_hr = create(:membership, organization: other, roles: %w[hr_admin])
      foreign = ActsAsTenant.with_tenant(other) do
        profile = register_employee(other, by: other_hr.user, position: create_position(other), name: "Outra Pessoa")
        model = ProcessTemplate.create!(kind: "onboarding", name: "Outra", status: "active")
        Processes::Start.call(template: model, employment: profile.employments.sole, started_by: other_hr.user, starter: other_hr)
      end

      get "/processes/#{foreign.id}"
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "for the manager" do
    before do
      instance
      sign_in_member(manager)
    end

    it "shows only the items assigned to them, without the history, and lets them resolve those (P-03-39)" do
      get "/processes/#{instance.id}"
      expect(response.body).to include("2 itens atribuídos a você", "Apresentar a equipe", "Aprovação do gestor")
      expect(response.body).not_to include("Conferir documentos", "Histórico", "Cancelar processo")

      patch "/processes/#{instance.id}/items/#{items["Aprovação do gestor"].id}/reject", params: { reason: "Falta o exame" }
      expect(items["Aprovação do gestor"]).to have_attributes(status: "rejected", completed_by: manager_user)

      patch "/processes/#{instance.id}/items/#{items["Conferir documentos"].id}/done"
      expect(response).to have_http_status(:forbidden)
      patch "/processes/#{instance.id}/items/#{items["Apresentar a equipe"].id}/skip", params: { skipped_reason: "x" }
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "for the HR analyst of another unit" do
    it "answers 404 (D-641, spec 03, section 4.4)" do
      instance
      other_unit = in_company { Unit.create!(name: "Bento") }
      analyst = create(:membership, organization: company, roles: %w[hr_analyst], enabled_modules: %w[admissao],
        user: create(:user, cpf: "98765432100"))
      in_company { MembershipUnit.create!(membership: analyst, unit: other_unit) }
      sign_in_member(analyst)

      get "/processes/#{instance.id}"
      expect(response).to have_http_status(:not_found)
    end
  end
end
