require "rails_helper"

RSpec.describe LegalDocument do
  let(:brand) { create(:brand) }

  it "numbers the versions per brand and kind (D-577)" do
    first = create(:legal_document, kind: "terms")
    second = create(:legal_document, kind: "terms")
    privacy = create(:legal_document, kind: "privacy")
    brand_terms = create(:legal_document, kind: "terms", brand: brand)

    expect([ first, second, privacy, brand_terms ].map(&:version)).to eq([ 1, 2, 1, 1 ])
  end

  it "never changes a published version (RN-02-017)" do
    document = create(:legal_document)

    expect { document.update!(body: "Outro texto") }.to raise_error(ActiveRecord::ReadOnlyRecord)
    expect { document.destroy }.to raise_error(ActiveRecord::ReadOnlyRecord)
  end

  describe ".current_for (D-578)" do
    it "uses the brand's latest version or, without one, the CatalystHR's" do
      create(:legal_document, kind: "terms")
      platform = create(:legal_document, kind: "terms")
      expect(described_class.current_for(brand, "terms")).to eq(platform)

      own = create(:legal_document, kind: "terms", brand: brand)
      expect(described_class.current_for(brand, "terms")).to eq(own)
      expect(described_class.current_for(create(:brand), "terms")).to eq(platform)
      expect(described_class.current_for(brand, "privacy")).to be_nil
    end
  end
end
