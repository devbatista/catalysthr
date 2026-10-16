require "rails_helper"

# Spec 05, RN-05-001, and spec 02, RN-02-086 (D-187, D-592).
RSpec.describe SensitiveData do
  it "shows the value outside an impersonate" do
    expect(described_class.reveal("12345678909", as: :cpf)).to eq("12345678909")
  end

  it "masks the value during an impersonate" do
    Current.impersonation = build(:impersonation_session)

    expect(described_class.reveal("123.456.789-09", as: :cpf)).to eq("***.456.789-**")
    expect(described_class.reveal(1_234_567, as: :money)).to eq("R$ ••••")
    expect(described_class.reveal("12345-6", as: :bank_account)).to eq("••••56")
  end

  it "refuses an unknown kind of value" do
    expect { described_class.mask("x", as: :salary) }.to raise_error(ArgumentError)
  end
end
