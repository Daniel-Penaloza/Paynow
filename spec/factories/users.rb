FactoryBot.define do
  factory :user do
    # association crea automáticamente una organización asociada
    association :organization
    sequence(:email_address) { |n| "usuario#{n}@ejemplo.com" }
    password { "password123" }
    role     { :business_owner }

    # trait es una variante de la factory — se activa con create(:user, :super_admin)
    trait :super_admin do
      organization { nil }
      role         { :super_admin }
    end
  end
end
