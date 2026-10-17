require "rails_helper"

RSpec.describe MoneyCents do
  it "reads amounts in reais into cents and writes them back" do
    expect(described_class.parse("R$ 2.500,50")).to eq(250_050)
    expect(described_class.parse("2500,5")).to eq(250_050)
    expect(described_class.parse("2500.50")).to eq(250_050)
    expect(described_class.parse(" ")).to be_nil
    expect(described_class.parse("dois mil")).to eq(:invalid)
    expect(described_class.format(250_050)).to eq("2.500,50")
    expect(described_class.format(1_000_000_00)).to eq("1.000.000,00")
  end
end
