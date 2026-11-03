require "rails_helper"

# Spec 08, block 08b (RN-08-030 to RN-08-054, D-643): the expirations and their notice,
# the "age" rule's check, the requests with their panel and the publications asking for an
# acknowledgment, with the confirmation, the refusal and the receipt.
RSpec.describe "Document follow-ups" do
  include ActiveJob::TestHelper

  let(:company) { create(:company, name: "Metalúrgica Serra Azul") }
  let(:hr_user) { create(:user, name: "Juliana Ribeiro") }
  let!(:hr) { create(:membership, user: hr_user, organization: company, roles: %w[hr_admin]) }
  let(:manager_user) { create(:user, name: "Carlos Mendes", cpf: "11144477735") }
  let!(:manager) { create(:membership, user: manager_user, organization: company, roles: %w[manager]) }
  let(:department) { Department.create!(name: "Logística", unit: company.headquarters).tap { |each| each.managers << manager } }
  let(:position) { create_position(company) }
  let(:profile) { register_employee(company, by: hr_user, position: position, name: "Marcos Teles", department: department) }
  let(:ability) { Ability.new(hr_user, area: :panel, company: company) }

  around { |example| ActsAsTenant.with_tenant(company) { example.run } }

  before do
    load_platform_document_types
    travel_to Time.zone.local(2026, 9, 20, 9)
  end

  after { travel_back }

  def type(code) = DocumentType.find_by!(code: code)

  def pdf(content = "%PDF-1.4\n%fake\n")
    Rack::Test::UploadedFile.new(StringIO.new(content), "application/pdf", original_filename: "doc.pdf")
  end

  def scan_clean(blobs)
    Array(blobs).each { |blob| blob.file_scan.record!(Antivirus::Clamd::Result.new(signature: nil)) }
    perform_enqueued_jobs(only: Documents::ConsolidatePdfJob)
  end

  def reviewed(code, person = profile)
    form = Documents::Upload.new(worker_profile: person, document_type: type(code), files: [ pdf ], by: hr_user)
    form.save
    scan_clean(form.version.files.blobs)
    form.version.reload
  end

  def notices(code) = Notification.where(notification_type: code)

  describe "the expirations (RN-08-030 to RN-08-032)" do
    it "puts the CNH in expiring on the notice's date and tells the HR and, with the text only, the manager (CA-08-004)" do
      version = reviewed("cnh")
      Documents::Review.new(version, by: hr_user).approve(valid_until: Date.new(2026, 11, 2))
      document = version.document.reload
      expect(document).to have_attributes(expires_on: Date.new(2026, 11, 2), status: "valid")

      travel_to(Time.zone.local(2026, 10, 2, 9)) { Documents::ExpirationsJob.perform_now }
      expect(document.reload.status).to eq("valid")
      expect(notices("documents.hr_expiring")).to be_empty

      travel_to(Time.zone.local(2026, 10, 3, 9)) do
        Documents::ExpirationsJob.perform_now
        Documents::ExpirationsJob.perform_now
      end
      expect(document.reload).to have_attributes(status: "expiring", expiration_alerted_on: Date.new(2026, 11, 2))
      hr_notice = notices("documents.hr_expiring").sole
      expect(hr_notice).to have_attributes(recipient_user_id: hr_user.id, path: "/documents/#{document.id}",
        title: "CNH de Marcos Teles vence em 02/11/2026")
      team_notice = notices("documents.team_expiring").sole
      expect(team_notice).to have_attributes(recipient_user_id: manager_user.id, path: "/employees/#{profile.id}")
      expect(team_notice.body).not_to include("/documents/")

      travel_to(Time.zone.local(2026, 11, 3, 9)) do
        Documents::ExpirationsJob.perform_now
      end
      expect(document.reload.status).to eq("expired")
      expect(notices("documents.hr_expiring").count).to eq(1)
    end

    it "counts the periodic ASO from its date, with the position's months (D-272)" do
      type("aso_periodic").position_expirations.create!(position: position, expiration_months: 6)
      version = reviewed("aso_periodic")
      Documents::Review.new(version, by: hr_user).approve(issued_on: Date.new(2026, 9, 1))

      expect(version.document.reload.expires_on).to eq(Date.new(2027, 3, 1))
    end

    it "only checks the \"age\" rule's date on the review, without expiring later (RN-08-033, CA-08-003, D-643)" do
      version = reviewed("proof_of_address")
      review = Documents::Review.new(version, by: hr_user)

      expect(review.approve(issued_on: Date.new(2026, 5, 23))).to be(false)
      expect(version.errors.full_messages).to include(a_string_including("Documento vencido: emitido há mais de 90 dias"))
      expect(review.approve(issued_on: Date.new(2026, 9, 1))).to be(true)
      expect(version.document.reload).to have_attributes(expires_on: nil, status: "valid")
    end
  end

  describe "the requests (RN-08-040, RN-08-041)" do
    it "counts 6 answered, 2 in review and 4 pending out of 12 (CA-08-005)" do
      people = Array.new(12) { |index| register_employee(company, by: hr_user, position: position, name: "Pessoa #{index + 1}") }
      form = Documents::RequestForm.new(document_type: type("school_statement"), audience_filter: { "unit_ids" => [ company.headquarters.id ] },
        due_on: Date.new(2026, 10, 15), message: "Declaração do semestre", by: hr_user, ability: ability)
      expect(form.save).to be(true)
      request = form.request
      expect(request.targets.count).to eq(12)
      expect(request.targets.map(&:document).map(&:status).uniq).to eq(%w[pending])

      request.targets.includes(:document).first(8).each_with_index do |target, index|
        upload = Documents::Upload.new(document: target.document, worker_profile: target.worker_profile, files: [ pdf ], by: hr_user)
        upload.save
        scan_clean(upload.version.files.blobs)
        Documents::Review.new(upload.version.reload, by: hr_user).approve if index < 6
      end

      expect(request.counts(request.targets.reload.to_a).slice("fulfilled", "in_review", "pending")).to eq("fulfilled" => 6, "in_review" => 2, "pending" => 4)
      travel_to(Time.zone.local(2026, 10, 16, 9)) { expect(request.counts(request.targets.reload.to_a)["late"]).to eq(4) }
      expect(people.size).to eq(12)
    end

    it "takes the group by the dependents' criterion, only people with an open employment" do
      with_dependent = register_employee(company, by: hr_user, position: position, name: "Ana Souza")
      with_dependent.dependents.create!(name: "Pedro", birth_date: Date.new(2020, 5, 1), relationship_type: "child", family_allowance: true)
      register_employee(company, by: hr_user, position: position, name: "Rita Lima")
      audience = Documents::Audience.new({ "family_allowance" => "1" }, ability: ability, document_type: type("school_statement"))

      expect(audience.filter).to eq("family_allowance" => true)
      expect(audience.profiles).to eq([ with_dependent ])
      expect(Documents::Audience.new({}, ability: ability, document_type: type("rg")).profiles).to be_empty
    end

    it "reaches only the analyst's units and categories" do
      branch = Unit.create!(name: "Filial Bento")
      outside = register_employee(company, by: hr_user, position: position, name: "Bruno Reis", unit: branch)
      profile
      analyst = create(:membership, organization: company, roles: %w[hr_analyst], status: "active", enabled_modules: %w[documentos])
      Memberships::AssignUnits.call(membership: analyst, unit_ids: [ branch.id ], by: hr_user)
      analyst_ability = Ability.new(analyst.user, area: :panel, company: company)
      all_units = { "unit_ids" => [ company.headquarters.id, branch.id ] }

      expect(Documents::Audience.new(all_units, ability: analyst_ability, document_type: type("rg")).profiles).to eq([ outside ])
      expect(Documents::Audience.new(all_units, ability: analyst_ability, document_type: type("bank_account_proof")).profiles).to be_empty
    end
  end

  describe "the acknowledgment (RN-08-050 to RN-08-054)" do
    let(:other) { register_employee(company, by: hr_user, position: position, name: "Lívia Prado") }

    def publish
      form = Documents::Publish.new(title: "Advertência de 20/09", document_type: type("school_statement"), file: pdf("%PDF-1.4 advertencia"),
        audience_filter: { "worker_profile_ids" => [ profile.id, other.id ] }, due_on: Date.new(2026, 9, 25), by: hr_user, ability: ability)
      expect(form.save).to be(true)
      form.publication
    end

    it "puts the same file, approved once clean, in each folder, waiting for the acknowledgment (D-643)" do
      publication = publish
      acknowledgments = publication.acknowledgments.to_a
      blob = acknowledgments.first.version.files.blobs.sole
      expect(acknowledgments.map { |each| each.version.files.blobs.sole }).to all(eq(blob))
      expect(FileScan.where(blob: blob).count).to eq(1)

      scan_clean(blob)
      expect(acknowledgments.map { |each| each.version.reload.status }).to eq(%w[approved approved])
      expect(acknowledgments.map { |each| each.document.reload.status }).to eq(%w[valid valid])
      expect(acknowledgments.map(&:status)).to eq(%w[awaiting awaiting])
      expect(DocumentVersion.where(status: "awaiting_review")).to be_empty
    end

    it "records the employee's confirmation with the date, IP, browser and hash, and the HR's receipt (CA-08-007)" do
      publication = publish
      scan_clean(publication.acknowledgments.first.version.files.blobs)
      acknowledgment = publication.acknowledgments.find_by!(worker_profile: profile)

      expect(Documents::Acknowledge.new(acknowledgment).confirm(by: other.user, ip: "200.1.2.3", user_agent: "Safari")).to be(false)
      expect(Documents::Acknowledge.new(acknowledgment).confirm(by: profile.user, ip: "200.1.2.3", user_agent: "Safari", comment: "Recebi")).to be(true)
      expect(acknowledgment.reload).to have_attributes(status: "acknowledged", ip: "200.1.2.3", user_agent: "Safari", comment: "Recebi",
        sha256: Digest::SHA256.hexdigest("%PDF-1.4 advertencia"), acknowledged_at: Time.current)
      expect(Documents::Acknowledge.new(acknowledgment).confirm(by: profile.user, ip: "1.1.1.1", user_agent: "x")).to be(false)

      text = Documents::AcknowledgmentReceipt.new(publication, publication.acknowledgments.includes(:version).to_a).render
      expect(text).to start_with("%PDF")
      expect(text.scan(%r{/Type\s*/Page\b(?!s)}).size).to be >= 1
    end

    it "lets the HR record the refusal only after the date, with up to two witnesses, the CPFs encrypted (RN-08-053)" do
      publication = publish
      scan_clean(publication.acknowledgments.first.version.files.blobs)
      acknowledgment = publication.acknowledgments.find_by!(worker_profile: other)
      witness = { "name" => "José Alves", "cpf" => "529.982.247-25" }

      expect(Documents::Acknowledge.new(acknowledgment).refuse(by: hr_user, note: "Recusou assinar", witnesses: [ witness ])).to be(false)
      travel_to(Time.zone.local(2026, 9, 26, 9)) do
        refusal = Documents::Acknowledge.new(acknowledgment)
        expect(refusal.refuse(by: hr_user, note: "Recusou", witnesses: [ witness, witness, witness ])).to be(false)
        expect(refusal.refuse(by: hr_user, note: "Recusou", witnesses: [ { "name" => "Sem CPF", "cpf" => "123" } ])).to be(false)
        expect(refusal.refuse(by: hr_user, note: "Recusou assinar o recebimento", witnesses: [ witness ])).to be(true)
      end

      expect(acknowledgment.reload).to have_attributes(status: "refused", recorded_by_id: hr_user.id,
        witnesses: [ { "name" => "José Alves", "cpf" => "52998224725" } ])
      raw = Acknowledgment.connection.select_value("SELECT witnesses FROM acknowledgments WHERE id = '#{acknowledgment.id}'")
      expect(raw).not_to include("52998224725")
      expect(PaperTrail::Version.where(item: acknowledgment).map(&:object_changes).compact.join).not_to include("52998224725")
    end
  end
end
