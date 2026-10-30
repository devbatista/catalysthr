require "rails_helper"

# Spec 06, block 06b-1 (P-06-01, P-06-02, D-232, CA-06-001): adopting makes an
# independent copy.
RSpec.describe ProcessTemplates::Adopt do
  let(:partner) { create(:partner) }
  let(:company) { create(:company, partner: partner) }
  let(:library) { SharedProcessTemplate.create!(kind: "admission", name: "Admissão CLT padrão", status: "active", description: "Base") }
  let(:user) { create(:user) }

  before do
    documents = library.items.create!(position: 1, kind: "task", title: "Conferir documentos", responsible_role: "hr")
    library.items.create!(position: 2, kind: "forward", title: "Encaminhar à contabilidade", responsible_role: "hr",
      config: { "validated_documents" => true }, depends_on_item_ids: [ documents.id ], due_anchor: "work_start",
      due_offset_days: -3, due_business_days: true, conditions: { "employment_kinds" => %w[clt] })
  end

  it "copies the library into a partner, as a draft with the dependencies mapped" do
    copy = described_class.call(library, into: partner, by: user)

    expect(copy).to have_attributes(partner: partner, status: "draft", name: "Admissão CLT padrão", source_template: library)
    first, second = copy.items.to_a
    expect(second).to have_attributes(title: "Encaminhar à contabilidade", depends_on_item_ids: [ first.id ], due_offset_days: -3,
      conditions: { "employment_kinds" => %w[clt] })
    expect(first.id).not_to eq(library.items.first.id)
  end

  # CA-06-001: the partner edits the original; the company's copy does not change.
  it "gives the company a copy the original's changes never reach (CA-06-001)" do
    partners = described_class.call(library, into: partner, by: user).tap(&:activate!)
    copy = ActsAsTenant.with_tenant(company) { described_class.call(partners, into: company, by: user) }

    partners.update!(name: "Admissão da Aurora")
    partners.items.first.update!(title: "Mudou no parceiro")

    ActsAsTenant.with_tenant(company) do
      expect(copy.reload).to have_attributes(name: "Admissão CLT padrão", company_id: company.id, source_template_id: partners.id)
      expect(copy.items.map(&:title)).to eq([ "Conferir documentos", "Encaminhar à contabilidade" ])
    end
  end

  # D-640: only the version in use, as the copy's first, in a file of its own.
  it "copies the acknowledgement's PDF in use, with its scan" do
    item = library.items.create!(position: 3, kind: "acknowledgement", title: "Regulamento interno", responsible_role: "employee")
    versions = [ "%PDF-1.4 versão 1", "%PDF-1.4 versão 2" ].each_with_index.map do |content, index|
      blob = ActiveStorage::Blob.create_and_upload!(io: StringIO.new(content), filename: "regulamento.pdf", content_type: "application/pdf")
      FileScan.create!(blob: blob, status: index.zero? ? "clean" : "scanning")
      item.materials.create!(version: index + 1, uploaded_by: user, file: blob)
    end

    copy = described_class.call(library, into: partner, by: user)

    material = copy.items.find_by!(kind: "acknowledgement").materials.sole
    expect(material).to have_attributes(version: 1, uploaded_by: user, scan_status: "clean")
    expect(material.file.blob).not_to eq(versions.first.file.blob)
    expect(material.file.download.force_encoding("UTF-8")).to eq("%PDF-1.4 versão 1")
  end
end
