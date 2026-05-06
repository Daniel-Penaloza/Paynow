FactoryBot.define do
  factory :receipt do
    association :business
    submitted_at        { Time.current }
    verification_status { "pending" }
    payer_name          { Faker::Name.full_name }
    payer_phone         { "5512345678" }

    # Adjunta un archivo de imagen mínimo para satisfacer la validación de presencia
    after(:build) do |receipt|
      receipt.file.attach(
        io:           StringIO.new("fake image content"),
        filename:     "comprobante.jpg",
        content_type: "image/jpeg"
      )
    end

    trait :verified do
      verification_status { "verified" }
      amount_cents        { 50_000 }
      transfer_date       { Date.current }
      bank_name           { "BBVA" }
      reference_number    { Faker::Number.number(digits: 8).to_s }
    end

    trait :rejected do
      verification_status { "rejected" }
    end

    trait :unreadable do
      verification_status { "unreadable" }
    end
  end
end
