require "rails_helper"
require "open3"

# Spec 08, block 08c (RN-08-060 to RN-08-063, RN-08-082, RN-08-083, D-644): the batch
# confirmed by hand, its expiration, the folder's ZIP, and the deletion with the 30 days of
# recovery.
RSpec.describe "Document batches, ZIP and deletion" do
  include ActiveJob::TestHelper

  let(:company) { create(:company, name: "Metalúrgica Serra Azul") }
  let(:hr_user) { create(:user, name: "Juliana Ribeiro") }
  let!(:hr) { create(:membership, user: hr_user, organization: company, roles: %w[hr_admin]) }
  let(:position) { create_position(company) }
  let(:profile) { register_employee(company, by: hr_user, position: position, name: "Marcos Teles") }
  let(:ability) { Ability.new(hr_user, area: :panel, company: company) }

  around { |example| ActsAsTenant.with_tenant(company) { example.run } }

  before { load_platform_document_types }

  def type(code) = DocumentType.find_by!(code: code)

  def pdf(content = "%PDF-1.4\n%fake\n", name = "aso.pdf")
    Rack::Test::UploadedFile.new(StringIO.new(content), "application/pdf", original_filename: name)
  end

  def clean(blobs, signature: nil)
    Array(blobs).each { |blob| blob.file_scan.record!(Antivirus::Clamd::Result.new(signature: signature)) }
  end

  def reviewed(code, person = profile)
    form = Documents::Upload.new(worker_profile: person, document_type: type(code), files: [ pdf ], by: hr_user)
    form.save
    clean(form.version.files.blobs)
    perform_enqueued_jobs(only: Documents::ConsolidatePdfJob)
    Documents::Review.new(form.version.reload, by: hr_user).approve
    form.document.reload
  end

  describe "the batch (RN-08-060 to RN-08-063)" do
    let(:batch) { DocumentBatch.create!(uploaded_by: hr_user) }
    let(:people) { Array.new(3) { |index| register_employee(company, by: hr_user, position: position, name: "Pessoa #{index + 1}") } }

    def add(count)
      Documents::BatchUpload.new(batch: batch, files: Array.new(count) { |index| pdf("%PDF-1.4 #{index}", "aso-#{index}.pdf") })
    end

    it "keeps every file out of the folders until confirmed, and leaves the unidentified ones in the batch (CA-08-006)" do
      expect(add(21).tap(&:save).errors.full_messages).to include("Arquivos podem ser até 20 por vez")
      expect(add(20).save).to be(true)
      expect(add(20).save).to be(true)
      expect(batch.items.count).to eq(40)
      clean(batch.items.map { |item| item.file.blob })

      choices = batch.items.first(37).to_h do |item|
        [ item.id, { "document_type_id" => type("aso_periodic").id, "worker_profile_id" => people.sample.id, "status" => "confirmed" } ]
      end
      review = Documents::BatchReview.new(batch, ability: ability, by: hr_user)
      expect(Document.count).to eq(0)
      expect(review.update(choices)).to be(true)
      expect(Document.count).to eq(0)

      expect(review.distribute).to eq(37)
      expect(Document.where(source: "batch").count).to eq(37)
      expect(batch.items.reload.map(&:status).tally).to eq("distributed" => 37, "pending" => 3)
      expect(batch.reload).to be_awaiting_confirmation
      perform_enqueued_jobs(only: Documents::ConsolidatePdfJob)
      expect(DocumentVersion.where(status: "awaiting_review").count).to eq(37)
    end

    it "takes at most 100 files" do
      stub_const("DocumentBatch::MAX_FILES", 3)
      add(2).save

      expect(add(2).tap(&:save).errors.full_messages).to include("Arquivos passam do limite de 3 por lote; ainda cabem 1")
    end

    it "confirms only a type and a person of the scope of who sent it, and never an infected file" do
      add(2).save
      first, second = batch.items.to_a
      clean(first.file.blob)
      clean(second.file.blob, signature: "Eicar")
      branch = Unit.create!(name: "Filial Bento")
      outside = register_employee(company, by: hr_user, position: position, name: "Bruno Reis", unit: branch)
      analyst = create(:membership, organization: company, roles: %w[hr_analyst], status: "active", enabled_modules: %w[documentos])
      Memberships::AssignUnits.call(membership: analyst, unit_ids: [ company.headquarters.id ], by: hr_user)
      analyst_batch = DocumentBatch.create!(uploaded_by: analyst.user)
      Documents::BatchUpload.new(batch: analyst_batch, files: [ pdf ]).save
      analyst_ability = Ability.new(analyst.user, area: :panel, company: company)

      review = Documents::BatchReview.new(analyst_batch, ability: analyst_ability, by: analyst.user)
      expect(review.update(analyst_batch.items.first.id => { "document_type_id" => type("rg").id, "worker_profile_id" => outside.id,
        "status" => "confirmed" })).to be(false)
      expect(review.errors.map(&:last)).to eq([ :out_of_scope ])

      review = Documents::BatchReview.new(batch, ability: ability, by: hr_user)
      expect(review.update(second.id => { "document_type_id" => type("rg").id, "worker_profile_id" => profile.id, "status" => "confirmed" }))
        .to be(false)
      expect(review.errors.map(&:last)).to eq([ :infected ])
      expect(review.update(first.id => { "status" => "confirmed" })).to be(false)
      expect(review.errors.map(&:last)).to include(:choice_blank)
    end

    it "warns 7 days before and, once expired, deletes the files not distributed (RN-08-062, P-08-17)" do
      add(2).save
      blobs = batch.items.map { |item| item.file.blob }

      travel_to(batch.expires_at - 8.days) { Documents::BatchExpirationsJob.perform_now }
      expect(Notification.where(notification_type: "documents.batch_expiring")).to be_empty
      travel_to(batch.expires_at - 6.days) do
        Documents::BatchExpirationsJob.perform_now
        Documents::BatchExpirationsJob.perform_now
      end
      notice = Notification.where(notification_type: "documents.batch_expiring").sole
      expect(notice).to have_attributes(recipient_user_id: hr_user.id, path: "/document-batches/#{batch.id}")

      travel_to(batch.expires_at + 1.hour) { Documents::BatchExpirationsJob.perform_now }
      expect(batch.reload).to be_expired
      perform_enqueued_jobs(only: ActiveStorage::PurgeJob)
      expect(ActiveStorage::Blob.where(id: blobs.map(&:id))).to be_empty
    end
  end

  describe "the deletion (RN-08-083)" do
    it "recovers within 30 days and, after them, deletes the files with no way back (CA-08-010)" do
      document = reviewed("rg")
      blob_ids = document.versions.flat_map { |version| version.files.blobs.map(&:id) }
      removal = Documents::Removal.new(document, by: hr_user)

      expect(removal.delete(reason: " ")).to be(false)
      expect(removal.delete(reason: "Enviado na pasta errada")).to be(true)
      expect(Document.kept).to be_empty
      expect(document.reload).to have_attributes(deleted_by_id: hr_user.id, delete_reason: "Enviado na pasta errada")

      travel_to(10.days.from_now) do
        expect(Documents::Removal.new(document, by: hr_user).restore).to be(true)
        expect(Document.kept).to eq([ document ])
        Documents::Removal.new(document, by: hr_user).delete(reason: "Duplicado")
      end

      travel_to(41.days.from_now) do
        Documents::PurgeDeletedJob.perform_now
        perform_enqueued_jobs(only: ActiveStorage::PurgeJob)
        expect(document.reload.purged_at).to be_present
        expect(ActiveStorage::Blob.where(id: blob_ids)).to be_empty
        expect(Documents::Removal.new(document, by: hr_user).restore).to be(false)
        expect(document.errors.full_messages).to include("O documento não pode mais ser recuperado")
      end
    end

    it "keeps a document answering an open process item or an acknowledgment waiting (D-644)" do
      template = ProcessTemplate.create!(kind: "admission", name: "Admissão CLT")
      template.items.create!(position: 1, kind: "document", title: "RG", responsible_role: "employee", config: { "document_type_id" => type("rg").id })
      template.update!(status: "active")
      instance = Processes::Start.call(template: template.reload, employment: profile.employments.sole, started_by: hr_user, starter: hr,
        anchors: { "work_start" => Date.current + 7 })
      form = Documents::Upload.new(worker_profile: profile, document_type: type("rg"), files: [ pdf ], by: hr_user,
        process_item: instance.items.sole)
      form.save

      expect(Documents::Removal.new(form.document, by: hr_user).delete(reason: "Errado")).to be(false)
      expect(form.document.errors.full_messages).to include(a_string_including("Dispense o item antes de excluir"))

      publication = Documents::Publish.new(title: "Aviso", document_type: type("school_statement"), file: pdf,
        audience_filter: { "worker_profile_ids" => [ profile.id ] }, due_on: Date.current + 3, by: hr_user, ability: ability)
      publication.save
      published = publication.publication.acknowledgments.sole.document
      expect(Documents::Removal.new(published, by: hr_user).delete(reason: "Errado")).to be(false)
    end

    it "gives a request a new pending document when its document is deleted (D-644)" do
      request_form = Documents::RequestForm.new(document_type: type("school_statement"), audience_filter: { "worker_profile_ids" => [ profile.id ] },
        by: hr_user, ability: ability)
      request_form.save
      target = request_form.request.targets.sole
      old = target.document

      expect(Documents::Removal.new(old, by: hr_user).delete(reason: "Arquivo trocado")).to be(true)
      expect(target.reload.document).not_to eq(old)
      expect(target.document).to have_attributes(status: "pending", deleted_at: nil)
    end

    it "keeps the file of a publication other folders still use" do
      other = register_employee(company, by: hr_user, position: position, name: "Lívia Prado")
      publish = Documents::Publish.new(title: "Aviso", document_type: type("school_statement"), file: pdf,
        audience_filter: { "worker_profile_ids" => [ profile.id, other.id ] }, due_on: Date.current + 3, by: hr_user, ability: ability)
      publish.save
      acknowledgments = publish.publication.acknowledgments.to_a
      blob = acknowledgments.first.version.files.blobs.sole
      acknowledgments.first.update!(status: "refused", refused_note: "Recusou", recorded_by: hr_user, recorded_at: Time.current)
      Documents::Removal.new(acknowledgments.first.document, by: hr_user).delete(reason: "Errado")

      travel_to(31.days.from_now) do
        Documents::PurgeDeletedJob.perform_now
        perform_enqueued_jobs(only: ActiveStorage::PurgeJob)
      end
      expect(ActiveStorage::Blob.exists?(blob.id)).to be(true)
      expect(acknowledgments.last.version.files.blobs.sole).to eq(blob)
    end
  end

  describe "the folder's ZIP (RN-08-082)" do
    it "has the versions in force the requester may read, by category, and an index (D-644)" do
      reviewed("rg")
      reviewed("aso_periodic")
      reviewed("bank_account_proof")
      analyst = create(:membership, organization: company, roles: %w[hr_analyst], status: "active", enabled_modules: %w[documentos])
      Memberships::AssignUnits.call(membership: analyst, unit_ids: [ company.headquarters.id ], by: hr_user)
      export = DocumentFolderExport.create!(worker_profile: profile, requested_by: analyst.user)

      Documents::ZipFolderJob.perform_now(export)
      expect(export.reload).to have_attributes(status: "ready", documents_count: 2)
      expect(export.expires_at).to be_within(1.minute).of(24.hours.from_now)
      expect(export.zip.blob.key).to start_with("companies/#{company.id}/exports/")

      entries = Dir.mktmpdir do |dir|
        path = File.join(dir, "pasta.zip")
        File.binwrite(path, export.zip.download)
        out, _err, status = Open3.capture3("7z", "l", "-slt", path)
        expect(status).to be_success
        out.scan(/^Path = (.+)$/).flatten.drop(1)
      end
      expect(entries).to include("documentos/Pessoais/RG.pdf", "documentos/Saúde/ASO periódico.pdf", "documentos/indice.txt")
      expect(entries.join).not_to include("Comprovante da conta")

      travel_to(25.hours.from_now) { Documents::PurgeDeletedJob.perform_now }
      expect(export.reload).to be_expired
    end
  end
end
