class Organization < ApplicationRecord
  PLAN_LIMITS = {
    "free"  => { businesses: 1, receipts_per_month: 50 },
    "basic" => { businesses: 1, receipts_per_month: 500 },
    "pro"   => { businesses: 5, receipts_per_month: Float::INFINITY }
  }.freeze

  TRIAL_DAYS = 365

  has_many :users, dependent: :destroy
  has_many :businesses, through: :users

  validates :name, presence: true
  validates :subdomain, presence: true, uniqueness: true,
            format: { with: /\A[a-z0-9\-]+\z/, message: "solo letras minúsculas, números y guiones" }
  validates :plan, inclusion: { in: %w[free basic pro] }
  validates :plan_status, inclusion: { in: %w[trialing active inactive] }

  before_validation :normalize_subdomain
  before_create :set_trial_end_date

  def on_trial?
    plan_status == "trialing" && trial_ends_at.present? && trial_ends_at >= Date.current
  end

  def plan_active?
    plan_status == "active" ||
      (plan_status == "trialing" && trial_ends_at.present? && trial_ends_at >= Date.current)
  end

  def within_business_limit?
    businesses.count < PLAN_LIMITS[plan][:businesses]
  end

  def within_receipt_limit?
    limit = PLAN_LIMITS[plan][:receipts_per_month]
    return true if limit == Float::INFINITY

    start_of_month = Date.current.beginning_of_month
    monthly_count = businesses
      .joins(:receipts)
      .where(receipts: { created_at: start_of_month.. })
      .count
    monthly_count < limit
  end

  private

  def normalize_subdomain
    self.subdomain = subdomain.to_s.strip.downcase.gsub(/[^a-z0-9\-]/, "-")
  end

  def set_trial_end_date
    self.trial_ends_at ||= TRIAL_DAYS.days.from_now.to_date
  end
end
