FactoryBot.define do
  factory :legal_document do
    kind { "terms" }
    body { "Texto fictício, só para testes." }
    association :published_by, factory: :user, platform_role: "superadmin"
  end
end
