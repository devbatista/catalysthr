require "rails_helper"
require "vips"

# Spec 08, block 08a (RN-08-001 to RN-08-024, RN-08-080, D-642): the upload with its checks,
# the scan, the single PDF, the review, the versions, the types the company turns off and
# the process's document item.
RSpec.describe "Documents" do
  include ActiveJob::TestHelper

  let(:company) { create(:company, name: "Metalúrgica Serra Azul") }
  let(:hr_user) { create(:user, name: "Juliana Ribeiro") }
  let!(:hr) { create(:membership, user: hr_user, organization: company, roles: %w[hr_admin]) }
  let(:position) { create_position(company) }
  let(:profile) { register_employee(company, by: hr_user, position: position, name: "Rafael Moura Campos") }
  let(:rg) { DocumentType.find_by!(code: "rg") }

  around { |example| ActsAsTenant.with_tenant(company) { example.run } }

  before { load_platform_document_types }

  def image(format = :jpg, width: 40, height: 30)
    picture = Vips::Image.black(width, height).add(200).cast(:uchar)
    data = format == :png ? picture.bandjoin([ picture, picture, picture ]).pngsave_buffer : picture.jpegsave_buffer
    Rack::Test::UploadedFile.new(StringIO.new(data), "image/#{format == :png ? "png" : "jpeg"}", original_filename: "foto.#{format}")
  end

  def pdf(name = "rg.pdf")
    Rack::Test::UploadedFile.new(StringIO.new("%PDF-1.4\n%fake\n"), "application/pdf", original_filename: name)
  end

  def upload(files, type: rg, document: nil, **links)
    Documents::Upload.new(worker_profile: profile, document_type: type, document: document, files: files, by: hr_user, **links)
  end

  def scan_all(version, result: Antivirus::Clamd::Result.new(signature: nil))
    version.files.blobs.each { |blob| blob.file_scan.record!(result) }
    perform_enqueued_jobs(only: Documents::ConsolidatePdfJob)
    version.reload
  end

  def page_count(data)
    data.scan(%r{/Type\s*/Page\b(?!s)}).size
  end

  describe "the upload (RN-08-010, RN-08-011)" do
    it "refuses a .docx and lists the accepted formats (CA-08-001)" do
      docx = Rack::Test::UploadedFile.new(StringIO.new("PK\x03\x04word"), "application/msword", original_filename: "rg.docx")
      form = upload([ docx ])

      expect(form.save).to be(false)
      expect(form.errors.full_messages).to include("Arquivos precisam ser PDF, JPG, PNG")
      expect(Document.count).to eq(0)
    end

    it "accepts a PDF only alone and no more images than the type takes (P-08-05)" do
      expect(upload([ pdf, image ]).tap(&:save).errors.full_messages).to include("Arquivos com um PDF, ele precisa ir sozinho")
      expect(upload([ image, image, image ]).tap(&:save).errors.full_messages).to include("Arquivos aceitam até 2 imagens para este tipo")
    end

    it "refuses a file over 10 MB" do
      big = Rack::Test::UploadedFile.new(StringIO.new("%PDF-1.4" + ("0" * 10.megabytes)), "application/pdf", original_filename: "big.pdf")

      expect(upload([ big ]).tap(&:save).errors.full_messages).to include("Arquivos podem ter até 10 MB cada")
    end

    it "stores each file under the company's prefix and waits for the scan (P-08-07, P-05-30)" do
      form = upload([ image, image(:png) ])
      expect(form.save).to be(true)

      version = form.version
      expect(version).to be_scanning
      expect(version.files.blobs.map(&:key)).to all(start_with("companies/#{company.id}/documents/"))
      expect(version.files.blobs.map { |blob| blob.file_scan.status }).to eq(%w[scanning scanning])
      expect(form.document).to have_attributes(status: "pending", source: "hr", worker_profile_id: profile.id)
    end

    it "joins the front and the back in a PDF of two pages once both are clean (CA-08-002)" do
      form = upload([ image, image(:png) ])
      form.save
      version = form.version

      version.files.blobs.first.file_scan.record!(Antivirus::Clamd::Result.new(signature: nil))
      perform_enqueued_jobs(only: Documents::ConsolidatePdfJob)
      expect(version.reload).to be_scanning

      scan_all(version)
      expect(version).to be_awaiting_review
      data = version.pdf.download
      expect(data).to start_with("%PDF")
      expect(page_count(data)).to eq(2)
      expect(version.sha256).to eq(Digest::SHA256.hexdigest(data))
      expect(version.pdf.blob.key).to start_with("companies/#{company.id}/documents/")
      expect(version.pdf.blob.file_scan).to be_clean
    end

    it "keeps a PDF as the single file" do
      form = upload([ pdf ])
      form.save
      version = scan_all(form.version)

      expect(version).to be_awaiting_review
      expect(version.pdf.blob).to eq(version.files.blobs.sole)
      expect(version.sha256).to eq(Digest::SHA256.hexdigest("%PDF-1.4\n%fake\n"))
    end

    it "rejects the version when a file has a virus (RN-08-020)" do
      form = upload([ image, image ])
      form.save
      version = scan_all(form.version, result: Antivirus::Clamd::Result.new(signature: "Eicar-Signature"))

      expect(version).to be_rejected_by_scan
      expect(version.pdf).not_to be_attached
    end

    it "stores nothing during an impersonate's simulation (RN-02-085)" do
      allow(Simulation).to receive(:active?).and_return(true)
      form = upload([ pdf ])

      expect(form.save).to be(true)
      expect(form.version.files).not_to be_attached
      expect(ActiveStorage::Blob.count).to eq(0)
    end
  end

  describe "the review (RN-08-021 to RN-08-023)" do
    def reviewed_version(document = nil)
      form = upload([ pdf ], document: document)
      form.save
      scan_all(form.version)
    end

    it "makes the approved version the one in force and the previous one replaced (D-280)" do
      first = reviewed_version
      expect(Documents::Review.new(first, by: hr_user).approve).to be(true)
      document = first.document.reload
      expect(document).to have_attributes(status: "valid", current_version_id: first.id)

      second = reviewed_version(document)
      expect(second.number).to eq(2)
      Documents::Review.new(second, by: hr_user).approve(valid_until: Date.new(2030, 1, 31))

      expect(first.reload).to be_replaced
      expect(second.reload).to have_attributes(status: "approved", reviewed_by_id: hr_user.id, valid_until: Date.new(2030, 1, 31))
      expect(document.reload.current_version).to eq(second)
    end

    it "asks a correction with a reason, and a note when the reason is \"Outro\" (RN-08-022, P-08-09)" do
      version = reviewed_version
      review = Documents::Review.new(version, by: hr_user)

      expect(review.request_correction(reason: nil)).to be(false)
      expect(review.request_correction(reason: "other", note: " ")).to be(false)
      expect(version.reload).to be_awaiting_review

      expect(review.request_correction(reason: "illegible")).to be(true)
      expect(version.reload).to have_attributes(status: "correction_requested", correction_reason: "illegible")
      expect(Documents::Review.new(version, by: hr_user).approve).to be(false)
    end
  end

  describe "the types (RN-08-002 to RN-08-004)" do
    it "lets the company turn off a platform's type without touching its documents (P-08-04)" do
      form = upload([ pdf ])
      form.save
      CompanyDocumentTypeSetting.create!(document_type: rg, enabled: false)

      expect(DocumentType.usable).not_to include(rg)
      expect(upload([ pdf ], type: DocumentType.find(rg.id)).tap(&:save).errors.full_messages).to include("Tipo de documento precisa ser um tipo ativo na empresa")
      expect(Document.kept.where(document_type: rg).count).to eq(1)
    end

    it "keeps the company's types to itself and the platform's to the team (RN-08-002)" do
      own = DocumentType.create!(name: "Certificado NR-35", category: "other")
      other = create(:company)

      expect(own.company_id).to eq(company.id)
      ActsAsTenant.with_tenant(other) { expect(DocumentType.where(id: own.id)).to be_empty }
      expect(PlatformDocumentType.where(id: own.id)).to be_empty
    end

    it "takes other months by position for a periodicity type (D-272)" do
      aso = DocumentType.find_by!(code: "aso_periodic")
      risky = create_position(company, name: "Soldador", cbo_code: "724315")
      aso.position_expirations.create!(position: risky, expiration_months: 6)

      expect(aso.months_for(risky)).to eq(6)
      expect(aso.months_for(position)).to eq(12)
      expect(rg.position_expirations.build(position: risky, expiration_months: 6)).not_to be_valid
    end
  end

  it "hides the internal types from the employee's folder (D-274, CA-08-008)" do
    internal = DocumentType.create!(name: "Advertência", category: "statements", internal: true)
    upload([ pdf ]).save
    upload([ pdf ], type: internal).save

    expect(Document.for_employee.map(&:document_type)).to eq([ rg ])
  end

  describe "the process's document item (RN-06-010, D-642)" do
    let(:template) { ProcessTemplate.create!(kind: "admission", name: "Admissão CLT") }
    let!(:item) do
      template.items.create!(position: 1, kind: "document", title: "RG", responsible_role: "employee",
        config: { "document_type_id" => rg.id })
    end
    let!(:after) do
      template.items.create!(position: 2, kind: "task", title: "Conferir a ficha", responsible_role: "hr", depends_on_item_ids: [ item.id ])
    end
    let(:instance) do
      template.update!(status: "active")
      Processes::Start.call(template: template.reload, employment: profile.employments.sole, started_by: hr_user, starter: hr,
        anchors: { "work_start" => Date.current + 7 })
    end
    let(:process_item) { instance.items.find_by!(title: "RG") }

    it "asks one active type per item in the editor" do
      expect(template.items.build(position: 3, kind: "document", title: "Sem tipo", responsible_role: "employee")).not_to be_valid
    end

    it "follows the document: sent, correction asked, then approved, which frees the next item" do
      form = upload([ pdf ], process_item: process_item)
      expect(form.save).to be(true)
      expect(form.document).to have_attributes(source: "process", source_ref: process_item)
      expect(process_item.reload).to be_submitted

      version = scan_all(form.version)
      Documents::Review.new(version, by: hr_user).request_correction(reason: "illegible")
      expect(process_item.reload).to be_correction_requested

      second = upload([ pdf ], document: form.document)
      second.save
      expect(process_item.reload).to be_submitted
      Documents::Review.new(scan_all(second.version), by: hr_user).approve
      expect(process_item.reload).to have_attributes(status: "approved", completed_by_id: hr_user.id)
      perform_enqueued_jobs(only: Processes::UnblockItemsJob)
      expect(instance.items.find_by!(title: "Conferir a ficha")).to be_pending
      expect(instance.events.pluck(:action)).to include("document_submitted", "document_correction_requested", "document_approved")
    end

    it "takes a document only of the item's type, while the item waits for it" do
      cpf = DocumentType.find_by!(code: "cpf")

      expect(upload([ pdf ], type: cpf, process_item: process_item).tap(&:save).errors.full_messages)
        .to include("O item do processo não está aguardando este documento")
    end
  end
end
