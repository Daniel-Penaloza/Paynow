class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy
  belongs_to :organization, optional: true
  has_many :businesses, dependent: :destroy

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  enum :role, { super_admin: 0, business_owner: 1 }, default: :business_owner

  validates :role, presence: true
  validate :super_admin_has_no_organization
  validate :business_owner_has_organization

  private

  def super_admin_has_no_organization
    errors.add(:organization, "debe estar vacío para super admin") if super_admin? && organization.present?
  end

  def business_owner_has_organization
    errors.add(:organization, "es requerida para dueños de negocio") if business_owner? && organization.blank?
  end
end
