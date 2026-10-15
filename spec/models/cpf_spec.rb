require "rails_helper"

RSpec.describe Cpf do
  it "accepts valid check digits, with or without punctuation" do
    expect(described_class.valid?("123.456.789-09")).to be(true)
    expect(described_class.valid?("12345678909")).to be(true)
  end

  it "rejects wrong check digits, wrong sizes and repeated digits" do
    expect(described_class.valid?("123.456.789-00")).to be(false)
    expect(described_class.valid?("1234567890")).to be(false)
    expect(described_class.valid?("111.111.111-11")).to be(false)
    expect(described_class.valid?("")).to be(false)
  end

  it "normalizes and formats" do
    expect(described_class.normalize(" 123.456.789-09 ")).to eq("12345678909")
    expect(described_class.format("12345678909")).to eq("123.456.789-09")
  end

  it "tells a CPF from an e-mail in the sign-in field (RN-02-003)" do
    expect(described_class.looks_like_cpf?("123.456.789-09")).to be(true)
    expect(described_class.looks_like_cpf?("12345678909")).to be(true)
    expect(described_class.looks_like_cpf?("maria@example.com")).to be(false)
    expect(described_class.looks_like_cpf?("maria123")).to be(false)
  end
end
