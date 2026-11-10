require "rails_helper"

# Spec 14, block 14b (D-670): the fields read are cleaned before use (RN-14-004, RN-14-022), the
# schema carries no personal data, the platform's types get their profiles (RN-14-021) and the
# evaluation set scores the reading with fictitious documents (RN-14-140), here with a recorded
# answer (RN-14-141).
RSpec.describe "AI extraction" do
  it "checks the PIS digits" do
    expect(Pis.valid?("120.56412.54-5")).to be(true)
    expect(Pis.valid?("12056412546")).to be(false)
    expect(Pis.valid?("11111111111")).to be(false)
  end

  it "keeps only the profile's keys, once, with the digits, the states and the real dates" do
    fields = Ai::Extraction.normalize([
      { "key" => "cpf", "value" => "529.982.247-25", "page" => 1, "confidence" => "high" },
      { "key" => "cpf", "value" => "00000000000", "page" => 2, "confidence" => "low" },
      { "key" => "rg_state", "value" => " rs ", "page" => 1, "confidence" => "high" },
      { "key" => "birth_date", "value" => "1990-02-30", "page" => 1, "confidence" => "high" },
      { "key" => "salary", "value" => "1000", "page" => 1, "confidence" => "high" }
    ], "rg")
    expect(fields.to_h { |field| [ field["key"], field["value"] ] }).to eq("cpf" => "52998224725", "rg_state" => "RS", "birth_date" => nil)
    expect(Ai::Extraction.clean("APTO", :aso_result)).to eq("fit")
  end

  it "sends a schema without personal data, only the field names and the fixed lists" do
    schema = Ai::Prompts::DocumentExtraction.schema("rg")
    keys = schema.dig(:properties, :fields, :items, :properties, :key, :enum)
    expect(keys).to eq(Ai::ExtractionProfiles.fields("rg").map(&:key))
    expect(schema.to_json).not_to match(/\d{3}/)
  end

  it "gives the platform's types their profiles, and refuses one on a company's type (RN-08-002, RN-14-025)" do
    load_platform_document_types
    expect(PlatformDocumentType.where.not(ai_extraction_profile: nil).pluck(:code, :ai_extraction_profile).to_h)
      .to include("rg" => "rg", "cnh" => "cnh", "pis" => "ctps_pis", "aso_periodic" => "aso")
    expect(PlatformDocumentType.find_by!(code: "dependent_cpf").ai_extraction_profile).to be_nil

    company = create(:company)
    ActsAsTenant.with_tenant(company) do
      type = DocumentType.new(name: "Crachá", category: "personal", ai_extraction_profile: "rg")
      expect(type).not_to be_valid
    end
  end

  it "scores the evaluation set by field and by type (RN-14-140)" do
    configure_anthropic
    test_case = Ai::Evaluation::CASES.first
    expect(Ai::Evaluation::CASES.map { |each| Ai::Evaluation.pdf(each) }).to all(start_with("%PDF"))

    fields = test_case.expected.except("detected_type").map { |key, value| { "key" => key, "value" => value, "page" => 1, "confidence" => "high" } }
    fields.find { |field| field["key"] == "rg_issuer" }["value"] = "DETRAN"
    stub_claude({ "detected_type" => "rg", "flags" => [], "fields" => fields })

    report = Ai::Evaluation.run([ test_case ])
    expect(report).to have_attributes(prompt_version: "document_extraction-1", model: "claude-sonnet-5-5", effort: "low", type_rate: 100.0)
    expect(report.rate).to eq(88.9)
    expect(report.results.sole[:fields].reject { |field| field[:hit] }.map { |field| field[:key] }).to eq(%w[rg_issuer])
    expect(WebMock).to(have_requested(:post, AnthropicHelpers::MESSAGES_URL).with { |request| JSON.parse(request.body).dig("output_config", "effort") == "low" })
    expect(AiRequest.count).to eq(0)
  end
end
