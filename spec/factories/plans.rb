FactoryBot.define do
  factory :plan do
    kind { "partner" }
    sequence(:name) { |n| "Até 500 colaboradores #{n}" }

    trait :direct do
      kind { "direct" }
      sequence(:name) { |n| "Empresa direta #{n}" }
    end
  end

  # A version with the fields of its plan's kind and the price of both modules (D-611).
  factory :plan_version do
    plan
    valid_from { Date.current }
    association :created_by, factory: :user, platform_role: "finance"
    ai_credit_overage_cents { 50 }
    whatsapp_overage_cents { 35 }

    after(:build) do |version|
      if version.plan.partner?
        version.monthly_price_cents ||= 150_000
        version.employee_limit ||= 500
        version.overage_per_employee_cents ||= 300
        version.ai_credits ||= 1_000
        version.whatsapp_messages ||= 2_000
      else
        version.price_per_employee_cents ||= 1_200
        version.minimum_monthly_cents ||= 30_000
        version.ai_credits_per_employee ||= 3
        version.whatsapp_messages_per_employee ||= 5
      end
      version.module_prices = { "ponto" => "400,00", "folha" => "600,00" } if version.plan_modules.empty?
    end
  end

  factory :add_on do
    code { "whatsapp_sender" }
  end

  factory :add_on_price do
    add_on
    valid_from { Date.current }
    monthly_price_cents { 9_900 }
    association :created_by, factory: :user, platform_role: "finance"
  end
end
