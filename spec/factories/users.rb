FactoryBot.define do
  # Fictional CPFs with valid check digits.
  sequence(:cpf) do |n|
    base = format("%09d", 100_000_000 + n)
    first = Cpf.check_digit(base)
    "#{base}#{first}#{Cpf.check_digit("#{base}#{first}")}"
  end

  factory :user do
    name { "Maria Souza" }
    cpf { generate(:cpf) }
    sequence(:email) { |n| "pessoa#{n}@example.com" }
    password { "Catalyst#2026" }

    trait :platform do
      platform_role { "support" }
    end
  end

  factory :membership do
    user
    association :organization, factory: :company
    roles { [ "hr_admin" ] }
    status { "active" }
  end
end

FactoryBot.define do
  factory :impersonation_session do
    association :impersonator, factory: :user, platform_role: "support"
    association :impersonated_user, factory: :user
    brand
    reason { "Chamado 123" }
    token_expires_at { 2.minutes.from_now }
  end
end
