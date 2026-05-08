FactoryBot.define do
  factory :organization do
    sequence(:name)      { |n| "Organización #{n}" }
    sequence(:subdomain) { |n| "org-#{n}" }
    plan        { "free" }
    plan_status { "active" }
    trial_ends_at { nil }
    current_period_ends_at { nil }

    trait :trialing do
      plan_status   { "trialing" }
      trial_ends_at { 365.days.from_now.to_date }
    end

    trait :trial_expired do
      plan_status   { "trialing" }
      trial_ends_at { 1.day.ago.to_date }
    end

    trait :inactive do
      plan_status { "inactive" }
    end

    trait :basic do
      plan { "basic" }
    end

    trait :pro do
      plan { "pro" }
    end
  end
end
