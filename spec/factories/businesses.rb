FactoryBot.define do
  factory :business do
    association :user
    sequence(:name) { |n| "Negocio #{n}" }
    # CLABE válida: 18 dígitos exactos
    clabe       { "#{Faker::Number.number(digits: 18)}" }
    holder_name { Faker::Name.full_name }
    whatsapp    { "5512345678" }
    instructions { "Pago con transferencia SPEI únicamente." }
    # El slug se genera automáticamente desde el nombre (before_validation en el modelo)
  end
end
