require "rails_helper"

# Spec 04, RN-04-080 and RN-04-081 (P-04-25, P-04-26, D-213, D-605).
RSpec.describe CustomFieldDefinition do
  let(:company) { create(:company) }
  let(:hr_admin) { create(:membership, organization: company, roles: %w[hr_admin]).user }
  let(:profile) { register_employee(company, by: hr_admin, position: create_position(company)) }

  around { |example| ActsAsTenant.with_tenant(company) { example.run } }

  it "derives a fixed key from the label and keeps the type" do
    field = described_class.create!(label: "Tamanho do uniforme", field_type: "select", options: [ "P", "M", "G", "" ])

    expect(field).to have_attributes(key: "tamanho_do_uniforme", options: %w[P M G])
    expect(described_class.create!(label: "Tamanho do uniforme!", field_type: "text").key).to eq("tamanho_do_uniforme_2")
    expect(field.update(field_type: "text")).to be(false)
    expect(described_class.new(label: "Turno", field_type: "select")).not_to be_valid
  end

  it "casts the values by type and refuses what does not fit" do
    expect(described_class.new(field_type: "number").cast("12,5")).to eq("12.5")
    expect(described_class.new(field_type: "number").cast("doze")).to eq(:invalid)
    expect(described_class.new(field_type: "date").cast("2026-02-30")).to eq(:invalid)
    expect(described_class.new(field_type: "boolean").cast("false")).to be(false)
    expect(described_class.new(field_type: "select", options: %w[P M]).cast("G")).to eq(:invalid)
  end

  it "keeps the values in the record and asks for the required ones when the HR saves it (D-605)" do
    size = described_class.create!(label: "Tamanho do uniforme", field_type: "select", options: %w[P M G], required: true)

    expect(profile.reload.save).to be(true)
    expect(profile.save(context: :record_edit)).to be(false)
    expect(profile.errors[:base]).to include("Tamanho do uniforme é obrigatório")

    profile.custom_field_values = { "tamanho_do_uniforme" => "M" }
    expect(profile.save(context: :record_edit)).to be(true)

    size.update!(status: "inactive")
    expect(profile.reload.custom_fields).to eq("tamanho_do_uniforme" => "M")
    expect(profile.missing_custom_fields).to be_empty
  end
end
