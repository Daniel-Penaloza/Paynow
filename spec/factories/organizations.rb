FactoryBot.define do
  factory :organization do
    # sequence garantiza que cada organización tenga un subdomain único en las pruebas
    sequence(:name)      { |n| "Organización #{n}" }
    sequence(:subdomain) { |n| "org-#{n}" }
  end
end
