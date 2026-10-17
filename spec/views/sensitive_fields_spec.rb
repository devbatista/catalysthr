require "rails_helper"

# Spec 05, RN-05-001 (P-05-06): a sensitive field shown outside the single point breaks
# this test. Every view line naming one of them must go through reveal_confirmed.
RSpec.describe "Sensitive fields in the views" do
  fields = WorkerProfile::DOCUMENT_FIELDS + WorkerProfile::HEALTH_FIELDS + %i[salary_cents]

  it "reach the page only through reveal_confirmed" do
    offending = Rails.root.glob("app/views/**/*.erb").flat_map do |file|
      File.readlines(file).each_with_index.filter_map do |line, index|
        next if line.include?("reveal_confirmed") || line.strip.start_with?("<%#")

        # A read of the attribute (profile.rg_number) or a form field bound to it
        # (form.text_field :rg_number); labels and translation keys do not count.
        named = fields.find { |field| line.match?(/\w\.#{field}\b|(?:field|area|select)\(?\s*:#{field}\b/) }
        "#{file.relative_path_from(Rails.root)}:#{index + 1} (#{named})" if named
      end
    end

    expect(offending).to be_empty
  end
end
