require "rails_helper"

# Spec 06, block 06b-1 (P-06-01, P-06-02, D-232, CA-06-001): adopting makes an
# independent copy.
RSpec.describe ProcessTemplates::Adopt do
  let(:partner) { create(:partner) }
  let(:company) { create(:company, partner: partner) }
  let(:library) { SharedProcessTemplate.create!(kind: "admission", name: "Admissão CLT padrão", status: "active", description: "Base") }

  before do
    documents = library.items.create!(position: 1, kind: "task", title: "Conferir documentos", responsible_role: "hr")
    library.items.create!(position: 2, kind: "forward", title: "Encaminhar à contabilidade", responsible_role: "hr",
      config: { "validated_documents" => true }, depends_on_item_ids: [ documents.id ], due_anchor: "work_start",
      due_offset_days: -3, due_business_days: true, conditions: { "employment_kinds" => %w[clt] })
  end

  it "copies the library into a partner, as a draft with the dependencies mapped" do
    copy = described_class.call(library, into: partner)

    expect(copy).to have_attributes(partner: partner, status: "draft", name: "Admissão CLT padrão", source_template: library)
    first, second = copy.items.to_a
    expect(second).to have_attributes(title: "Encaminhar à contabilidade", depends_on_item_ids: [ first.id ], due_offset_days: -3,
      conditions: { "employment_kinds" => %w[clt] })
    expect(first.id).not_to eq(library.items.first.id)
  end

  # CA-06-001: the partner edits the original; the company's copy does not change.
  it "gives the company a copy the original's changes never reach (CA-06-001)" do
    partners = described_class.call(library, into: partner).tap(&:activate!)
    copy = ActsAsTenant.with_tenant(company) { described_class.call(partners, into: company) }

    partners.update!(name: "Admissão da Aurora")
    partners.items.first.update!(title: "Mudou no parceiro")

    ActsAsTenant.with_tenant(company) do
      expect(copy.reload).to have_attributes(name: "Admissão CLT padrão", company_id: company.id, source_template_id: partners.id)
      expect(copy.items.map(&:title)).to eq([ "Conferir documentos", "Encaminhar à contabilidade" ])
    end
  end
end
