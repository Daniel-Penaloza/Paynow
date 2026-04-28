class Organization < ApplicationRecord
  has_many :users, dependent: :destroy
  has_many :businesses, through: :users

  validates :name, presence: true
  validates :subdomain, presence: true, uniqueness: true,
            format: { with: /\A[a-z0-9\-]+\z/, message: "solo letras minúsculas, números y guiones" }

  before_validation :normalize_subdomain

  private

  def normalize_subdomain
    self.subdomain = subdomain.to_s.strip.downcase.gsub(/[^a-z0-9\-]/, "-")
  end
end
