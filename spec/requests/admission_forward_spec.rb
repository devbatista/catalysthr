require "rails_helper"

# Spec 07, block 07d-2 (RN-07-070, RN-06-065, RN-06-066, RN-02-073, D-143, D-651, D-652): the
# admission forwarded to the accounting firm, read and confirmed in the firm's area.
RSpec.describe "Admission forward", type: :request do
  include ActiveJob::TestHelper

  let(:partner) { create(:partner) }
  let(:partner_brand) { create(:brand, owner: partner, commercial_name: "Aurora RH") }
  let(:company) { create(:company, partner: partner, name: "Padaria Pão Quente", uses_accounting_step: true) }
  let(:hr_user) { create(:user, name: "Juliana Ribeiro", cpf: "52998224725") }
  let!(:hr) { create(:membership, user: hr_user, organization: company, roles: %w[hr_admin]) }
  let(:firm) { create(:accounting_firm, name: "Contábil Exata") }
  let!(:link) { create(:accounting_firm_company, accounting_firm: firm, company: company) }
  let(:accountant_user) { create(:user, name: "Carla Contadora", cpf: "39053344705") }
  let!(:accountant) { create(:membership, user: accountant_user, organization: firm, roles: %w[accountant]) }
  let(:position) { create_position(company, name: "Padeiro") }
  let(:department) { in_company { Department.create!(name: "Produção", unit: company.headquarters) } }
  let(:forward_config) { { "record" => true, "validated_documents" => true } }
  let!(:template) do
    in_company do
      ProcessTemplate.create!(kind: "admission", name: "Admissão padrão").tap do |model|
        model.items.create!(position: 1, kind: "forward", title: "Encaminhar à contabilidade", responsible_role: "accountant",
          config: forward_config)
        model.update!(status: "active")
        model.make_default!
      end
    end
  end
  let(:admission) { admit }
  let(:instance) { in_company { admission.process_instance } }
  let(:forward) { in_company { instance.items.find_by!(kind: "forward") } }
  let(:pdf) { Rack::Test::UploadedFile.new(StringIO.new("%PDF-1.4\n%fake\n"), "application/pdf", original_filename: "doc.pdf") }

  before do
    Flipper.enable(FeatureFlags::SIGN_IN)
    Flipper.enable(FeatureFlags::ADMISSIONS)
    publish_platform_legal_documents
    load_platform_document_types
    partner_brand.subdomains.create!(slug: "aurora")
    host! "aurora.painel.catalysthr.com.br"
  end

  def in_company(&)
    ActsAsTenant.with_tenant(company, &)
  end

  def sign_in_hr
    user = enable_mfa(hr_user)
    accept_legal_documents(user, partner_brand)
    sign_in_with_mfa(user.cpf, user)
    post "/current-company", params: { company_id: company.id }
  end

  def sign_in_accountant(membership = accountant)
    user = enable_mfa(membership.user)
    accept_legal_documents(user, partner_brand)
    sign_in_with_mfa(user.cpf, user)
  end

  def confirm_password
    post "/confirm-password", params: { password: "Catalyst#2026", return_to: request.fullpath }
  end

  def admit(cpf: "11144477735")
    in_company do
      registration = AdmissionRegistration.new(name: "Rafael Campos", cpf: cpf, email: "#{cpf}@example.com", kind: "clt",
        category: "standard", started_on: Date.current + 10, position_id: position.id, unit_id: company.headquarters.id,
        department_id: department.id)
      raise registration.errors.full_messages.to_sentence unless registration.save(company: company.reload, by: hr_user, starter: hr)

      registration.admission
    end
  end

  def aso_item
    in_company { instance.items.find_by!(kind: "document") }
  end

  def upload(type, item:)
    in_company do
      form = Documents::Upload.new(worker_profile: admission.worker_profile, document_type: type, files: [ pdf ], by: hr_user, process_item: item)
      raise form.errors.full_messages.to_sentence unless form.save

      form.version.files.blobs.each { |blob| blob.file_scan.record!(Antivirus::Clamd::Result.new(signature: nil)) }
      perform_enqueued_jobs(only: Documents::ConsolidatePdfJob)
      form.version.reload
    end
  end

  def approve_aso
    version = upload(in_company { Admissions::Aso.type }, item: aso_item)
    in_company { Documents::Review.new(version, by: hr_user).approve(issued_on: Date.current, aso_result: "fit") }
    in_company { Processes::Unblock.call(instance) }
    version
  end

  # A required document of another category, approved in the process.
  def approve_personal
    type = in_company { DocumentType.usable.where(category: "personal").order(:name).first }
    item = in_company do
      instance.items.create!(kind: "document", title: type.name, responsible_role: "hr", required: true, status: "pending", position: 90,
        config: { "document_type_id" => type.id })
    end
    version = upload(type, item: item)
    in_company { Documents::Review.new(version, by: hr_user).approve(issued_on: Date.current) }
    version
  end

  def send_forward
    approve_aso
    in_company { expect(Processes::ItemActions.new(forward.reload, by: hr_user).send_to_firm).to be(true) }
  end

  describe "the item in the process (RN-07-070, D-652)" do
    it "waits for every required document, also the ones the position brought" do
      admission
      in_company do
        expect(forward.status).to eq("blocked")
        expect(forward.depends_on).to contain_exactly(instance.items.find_by!(kind: "document"))
      end
      approve_aso
      in_company { expect(forward.reload.status).to eq("pending") }
    end

    it "offers the firm and the record by hand to the HR, and shows it sent" do
      approve_aso
      sign_in_hr
      get "/processes/#{instance.id}"
      expect(response.body).to include("Encaminhar ao escritório", "Registrar envio")

      patch "/processes/#{instance.id}/items/#{forward.id}/send-to-firm"
      expect(response).to redirect_to("/processes/#{instance.id}#items")
      follow_redirect!
      expect(response.body).to include("Encaminhado a Contábil Exata", "aguardando a confirmação do escritório", "Registrar envio")
      expect(response.body).not_to include("Encaminhar ao escritório")
      in_company do
        expect(forward.reload.status).to eq("sent")
        expect(instance.events.pluck(:action)).to include("item_sent_to_firm")
        # The HR panel's recent activity (RN-17-011, D-657).
        event = ActivityEvent.find_by!(kind: "admission_forwarded")
        expect(event.text).to eq("Juliana Ribeiro encaminhou a admissão de Rafael Campos ao escritório Contábil Exata")
        expect([ event.module_code, event.url, event.unit_id ]).to eq([ "admissao", "/admissions/#{admission.id}", company.headquarters.id ])
      end
    end

    it "refuses while a required document is missing, in an item the HR added" do
      admission
      added = in_company do
        instance.items.create!(kind: "forward", title: "Outro envio", responsible_role: "hr", status: "pending", position: 50, config: forward_config)
      end
      in_company do
        actions = Processes::ItemActions.new(added, by: hr_user)
        expect(actions.send_to_firm).to be(false)
        expect(added.errors.full_messages.to_sentence).to include("documentos obrigatórios")
      end
    end

    it "has only the record by hand without a linked firm (RN-06-066)" do
      link.update!(status: "ended", ended_at: Time.current)
      approve_aso
      sign_in_hr
      get "/processes/#{instance.id}"
      expect(response.body).to include("Registrar envio")
      expect(response.body).not_to include("Encaminhar ao escritório")
      in_company { expect(Processes::ItemActions.new(forward.reload, by: hr_user).send_to_firm).to be(false) }
    end

    it "tells the firm's team without sensitive data" do
      send_forward
      notification = Notification.find_by!(notification_type: "accounting.admission_forwarded", recipient_user: accountant_user)
      expect(notification.title).to eq("Admissão encaminhada: Rafael Campos")
      expect(notification.body).to include("Padaria Pão Quente")
      expect(notification.path).to eq("/firm/forwards/#{forward.id}")
      expect(notification.brand).to eq(company.subdomain_brand)
    end

    it "shows the accounting's status in the conclusion's summary (RN-07-081)" do
      send_forward
      sign_in_hr
      get "/admissions/#{admission.id}"
      expect(response.body).to include("Contabilidade")
    end
  end

  describe "the firm's area" do
    before do
      send_forward
      in_company do
        profile = admission.worker_profile
        profile.update!(rg_number: "123456789", disability: { "types" => [ "visual" ], "notes" => "cegueira" })
        admission.employment.revisions.sole.update!(salary_cents: 250_000)
      end
    end

    it "lists what was forwarded and asks for the password to open it" do
      sign_in_accountant
      get "/firm/forwards"
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Rafael Campos", "Padaria Pão Quente", "Aguardando confirmação")
      expect(response.body).not_to include("123456789")

      get "/firm/forwards/#{forward.id}"
      expect(response).to redirect_to(%r{/confirm-password\?return_to=})
    end

    it "shows the record without health, as access events of the company" do
      sign_in_accountant
      get "/firm/forwards/#{forward.id}"
      follow_redirect!
      post "/confirm-password", params: { password: "Catalyst#2026", return_to: "/firm/forwards/#{forward.id}" }
      follow_redirect!
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("123456789", "R$ 2.500,00", "Padeiro")
      expect(response.body).not_to include("cegueira", "Deficiência")

      events = AccessEvent.where(user: accountant_user, company: company, kind: "sensitive_read")
      expect(events.pluck(:action)).to include("firm_forward_opened", "view")
      expect(events.pluck(:field)).to include("rg_number", "salary_cents")
    end

    it "lists the approved documents, never health, and each opening is an event" do
      version = approve_personal
      sign_in_accountant
      get "/firm/forwards/#{forward.id}"
      confirm_password_for_forward
      expect(response.body).to include(in_company { version.document.document_type.name })
      expect(response.body).not_to include("ASO")

      document = in_company { version.document }
      get "/firm/forwards/#{forward.id}/documents/#{document.id}"
      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("application/pdf")
      expect(response.headers["Cache-Control"]).to include("no-store")
      expect(AccessEvent.where(user: accountant_user, company: company, action: "document_opened", subject: version).count).to eq(1)

      aso = in_company { Document.find_by!(source_ref: aso_item) }
      get "/firm/forwards/#{forward.id}/documents/#{aso.id}"
      expect(response).to have_http_status(:not_found)
    end

    it "doesn't open a file without the password" do
      version = approve_personal
      sign_in_accountant
      get "/firm/forwards/#{forward.id}/documents/#{in_company { version.document_id }}"
      expect(response).to have_http_status(:not_found)
    end

    it "hides the record when the item didn't choose it" do
      in_company { forward.update!(config: { "validated_documents" => true }) }
      sign_in_accountant
      get "/firm/forwards/#{forward.id}"
      confirm_password_for_forward
      expect(response.body).not_to include("123456789")
      expect(response.body).to include("Documentos validados")
    end

    it "confirms the receipt once and keeps it readable while linked (D-143, D-652)" do
      sign_in_accountant
      patch "/firm/forwards/#{forward.id}/confirm"
      expect(response).to redirect_to("/firm/forwards/#{forward.id}")
      in_company do
        item = forward.reload
        expect(item.status).to eq("received")
        expect(item.completed_by).to eq(accountant_user)
        expect(instance.events.pluck(:action)).to include("item_received")
      end
      patch "/firm/forwards/#{forward.id}/confirm"
      expect(flash[:alert]).to be_present

      get "/firm/forwards"
      expect(response.body).to include("Recebido")
    end

    it "gives the firm's whole team the access" do
      admin = create(:membership, user: create(:user, cpf: "71428793860"), organization: firm, roles: %w[firm_admin])
      sign_in_accountant(admin)
      get "/firm/forwards"
      expect(response.body).to include("Rafael Campos")
    end

    it "answers 404 to another firm" do
      other_firm = create(:accounting_firm, name: "Outro Escritório")
      other_company = create(:company, partner: partner, name: "Outra Empresa")
      create(:accounting_firm_company, accounting_firm: other_firm, company: other_company)
      other = create(:membership, user: create(:user, cpf: "71428793860"), organization: other_firm, roles: %w[accountant])
      sign_in_accountant(other)
      get "/firm/forwards"
      expect(response.body).not_to include("Rafael Campos")
      get "/firm/forwards/#{forward.id}"
      expect(response).to have_http_status(:not_found)
      patch "/firm/forwards/#{forward.id}/confirm"
      expect(response).to have_http_status(:not_found)
      in_company { expect(forward.reload.status).to eq("sent") }
    end

    it "answers 404 to the HR, who has no firm" do
      sign_in_hr
      get "/firm/forwards/#{forward.id}"
      expect(response).to have_http_status(:not_found)
    end

    it "ends with the admission cancelled" do
      in_company { Admissions::Cancellation.call(admission, reason: "withdrew", note: nil, by: hr_user) }
      sign_in_accountant
      get "/firm/forwards"
      expect(response.body).not_to include("Rafael Campos")
      get "/firm/forwards/#{forward.id}"
      expect(response).to have_http_status(:not_found)
    end

    it "ends when the HR records the sending by hand" do
      receipt = Rack::Test::UploadedFile.new(StringIO.new("%PDF-1.4\n%fake\n"), "application/pdf", original_filename: "envio.pdf")
      in_company do
        expect(Processes::ItemActions.new(forward.reload, by: hr_user).forward(sent_on: Date.current, receipt: receipt)).to be(true)
        expect(forward.reload.status).to eq("done")
      end
      sign_in_accountant
      get "/firm/forwards/#{forward.id}"
      expect(response).to have_http_status(:not_found)
    end

    it "ends at once when the firm is unlinked, and what wasn't confirmed goes back (RN-02-073)" do
      AccountingFirms::Unlink.call(link: link, by: hr_user)
      in_company do
        expect(forward.reload.status).to eq("pending")
        expect(forward.result).not_to include("accounting_firm_id")
        expect(instance.events.pluck(:action)).to include("item_forward_returned")
      end
    end

    it "closes the door of a firm that still serves another company" do
      other_company = create(:company, partner: partner, name: "Outra Empresa")
      create(:accounting_firm_company, accounting_firm: firm, company: other_company)
      sign_in_accountant
      get "/firm/forwards"
      expect(response.body).to include("Rafael Campos")

      AccountingFirms::Unlink.call(link: link, by: hr_user)
      get "/firm/forwards"
      expect(response.body).not_to include("Rafael Campos")
      get "/firm/forwards/#{forward.id}"
      expect(response).to have_http_status(:not_found)
    end

    it "keeps a confirmed item away from a new firm" do
      in_company { Processes::ItemActions.new(forward.reload, by: accountant_user).confirm_receipt }
      AccountingFirms::Unlink.call(link: link, by: hr_user)
      in_company { expect(forward.reload.status).to eq("received") }

      new_firm = create(:accounting_firm, name: "Novo Escritório")
      create(:accounting_firm_company, accounting_firm: new_firm, company: company)
      member = create(:membership, user: create(:user, cpf: "71428793860"), organization: new_firm, roles: %w[accountant])
      sign_in_accountant(member)
      get "/firm/forwards"
      expect(response.body).not_to include("Rafael Campos")
    end

    it "stays out while the flag is off" do
      sign_in_accountant
      Flipper.disable(FeatureFlags::ADMISSIONS)
      get "/firm/forwards"
      expect(response).to have_http_status(:not_found)
    end
  end

  def confirm_password_for_forward
    post "/confirm-password", params: { password: "Catalyst#2026", return_to: "/firm/forwards/#{forward.id}" }
    follow_redirect!
  end
end
