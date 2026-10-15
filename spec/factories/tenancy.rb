FactoryBot.define do
  # Fictional CNPJs with valid check digits.
  sequence(:cnpj) do |n|
    base = format("%08d0001", 10_000_000 + n)
    first = Cnpj.check_digit(base)
    "#{base}#{first}#{Cnpj.check_digit("#{base}#{first}")}"
  end

  factory :partner do
    name { "Aurora Gestão de Pessoas" }
    legal_name { "Aurora Gestão de Pessoas Ltda" }
    cnpj { generate(:cnpj) }
  end

  factory :company do
    name { "Metalúrgica Serra Azul" }
    legal_name { "Metalúrgica Serra Azul Ltda" }
    cnpj { generate(:cnpj) }

    trait :with_partner do
      partner
    end
  end

  factory :brand do
    association :owner, factory: :partner
    commercial_name { "Aurora RH" }
  end

  factory :brand_subdomain do
    brand
    sequence(:slug) { |n| "marca#{n}" }
  end
end

FactoryBot.define do
  factory :accounting_firm do
    name { "Contábil Exata" }
    cnpj { generate(:cnpj) }
  end

  factory :accounting_firm_company do
    accounting_firm
    company
    status { "active" }
    accepted_at { status == "active" ? Time.current : nil }
  end
end
