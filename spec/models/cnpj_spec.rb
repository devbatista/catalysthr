require "rails_helper"

RSpec.describe Cnpj do
  describe ".valid?" do
    it "accepts a numeric CNPJ, formatted or not" do
      expect(described_class.valid?("11.222.333/0001-81")).to be(true)
      expect(described_class.valid?("11222333000181")).to be(true)
    end

    it "accepts the alphanumeric example from the Receita Federal manual" do
      expect(described_class.valid?("12.ABC.345/01DE-35")).to be(true)
      expect(described_class.valid?("12.abc.345/01de-35")).to be(true)
    end

    it "rejects wrong check digits, letters in the check digits, wrong lengths and repeated characters" do
      expect(described_class.valid?("11.222.333/0001-82")).to be(false)
      expect(described_class.valid?("12.ABC.345/01DE-36")).to be(false)
      expect(described_class.valid?("12ABC34501DE3A")).to be(false)
      expect(described_class.valid?("1122233300018")).to be(false)
      expect(described_class.valid?("11111111111111")).to be(false)
      expect(described_class.valid?(nil)).to be(false)
    end
  end

  it "normalizes and formats" do
    expect(described_class.normalize("12.abc.345/01de-35")).to eq("12ABC34501DE35")
    expect(described_class.format("12ABC34501DE35")).to eq("12.ABC.345/01DE-35")
  end
end
