require "rails_helper"

RSpec.describe User do
  def errors_on(record, attribute)
    record.validate
    record.errors[attribute]
  end

  describe "CPF (RN-02-001)" do
    it "is stored encrypted and still found by value (D-086)" do
      user = create(:user, cpf: "123.456.789-09")

      stored = described_class.connection.select_value("SELECT cpf FROM users WHERE id = #{user.id}")
      expect(stored).not_to include("12345678909")
      expect(described_class.find_by(cpf: "123.456.789-09")).to eq(user)
    end

    it "is required, valid and unique" do
      create(:user, cpf: "12345678909")

      expect(build(:user, cpf: nil)).to be_invalid
      expect(errors_on(build(:user, cpf: "12345678900"), :cpf)).to include("não é um CPF válido")
      expect(errors_on(build(:user, cpf: "123.456.789-09"), :cpf)).to include("já está em uso")
    end

    it "is filtered from inspections and logs" do
      expect(create(:user, cpf: "12345678909").inspect).not_to include("12345678909")
    end
  end

  describe "contact (RN-02-002, P-02-04)" do
    it "needs an e-mail or a mobile phone" do
      expect(build(:user, email: nil, mobile_phone: nil)).to be_invalid
      expect(build(:user, email: nil, mobile_phone: "(11) 98765-4321")).to be_valid
      expect(build(:user, email: "maria@example.com", mobile_phone: nil)).to be_valid
    end

    it "keeps the e-mail unique, ignoring case" do
      create(:user, email: "Maria@Example.com")

      expect(errors_on(build(:user, email: "maria@example.com"), :email)).to include("já está em uso")
    end
  end

  describe "password (RN-02-030)" do
    it "refuses a password without uppercase and symbol (CA-02-004)" do
      errors = errors_on(build(:user, password: "catalyst1"), :password)

      expect(errors).to include("precisa ter pelo menos uma letra maiúscula", "precisa ter pelo menos um símbolo")
    end

    it "requires 8 characters and a number" do
      errors = errors_on(build(:user, password: "Ab#"), :password)

      expect(errors).to include("precisa ter pelo menos 8 caracteres", "precisa ter pelo menos um número")
    end

    it "refuses the CPF or the birth date inside the password (P-02-13)" do
      user = build(:user, cpf: "123.456.789-09", birth_date: Date.new(1990, 3, 15))

      [ "Senha#12345678909", "Senha#123.456.789-09", "Maria#15031990", "Maria#1990-03-15", "Maria#150390" ].each do |password|
        user.password = password
        expect(errors_on(user, :password)).to include("não pode conter o CPF nem a data de nascimento"), password
      end
    end

    it "accepts a password that follows the rules" do
      expect(build(:user, password: "Catalyst#2026")).to be_valid
    end
  end

  describe ".find_by_login (RN-02-003, P-02-05)" do
    let!(:user) { create(:user, cpf: "12345678909", email: "maria@example.com") }

    it "finds by CPF with or without the mask, and by e-mail in any case" do
      expect(described_class.find_by_login("123.456.789-09")).to eq(user)
      expect(described_class.find_by_login("12345678909")).to eq(user)
      expect(described_class.find_by_login(" Maria@Example.com ")).to eq(user)
      expect(described_class.find_by_login("")).to be_nil
    end
  end

  describe ".allowed_at (RN-02-004, RN-01-002)" do
    let(:partner) { create(:partner) }
    let(:partner_brand) { create(:brand, owner: partner) }
    let(:partner_company) { create(:company, partner: partner) }
    let(:direct_company) { create(:company) }
    let(:direct_brand) { create(:brand, owner: direct_company, commercial_name: "Serra Azul") }

    it "lets the CatalystHR team in only at the admin host (P-02-06)" do
      staff = create(:user, :platform)
      create(:membership, user: staff, organization: partner_company)

      expect(described_class.allowed_at(area: :admin, brand: nil)).to include(staff)
      expect(described_class.allowed_at(area: :panel, brand: partner_brand)).not_to include(staff)
    end

    it "lets a person in at the brand of the partner or of the direct company where the membership is" do
      consultant = create(:membership, organization: partner, roles: [ "consultant" ]).user
      hr = create(:membership, organization: partner_company).user
      direct_hr = create(:membership, organization: direct_company).user

      expect(described_class.allowed_at(area: :panel, brand: partner_brand)).to contain_exactly(consultant, hr)
      expect(described_class.allowed_at(area: :panel, brand: direct_brand)).to contain_exactly(direct_hr)
      expect(described_class.allowed_at(area: :admin, brand: nil)).to be_empty
    end

    it "counts only active and read-only memberships" do
      statuses = %w[invited active suspended read_only revoked]
      users = statuses.to_h { |status| [ status, create(:membership, organization: partner_company, status: status).user ] }

      expect(described_class.allowed_at(area: :panel, brand: partner_brand)).to contain_exactly(users["active"], users["read_only"])
    end
  end

  it "does not let a deactivated person sign in" do
    user = create(:user, status: "deactivated")

    expect(user.active_for_authentication?).to be(false)
    expect(user.inactive_message).to eq(:invalid)
  end
end
