class Business < ApplicationRecord
  belongs_to :user
  has_many :receipts, dependent: :destroy

  validates :name, presence: true
  validates :clabe, presence: true, length: { is: 18 }, format: { with: /\A\d+\z/, message: "solo dígitos" }
  validates :holder_name, presence: true
  validates :slug, presence: true, uniqueness: true

  before_validation :generate_slug, if: -> { slug.blank? && name.present? }

  def qr_code
    RQRCode::QRCode.new(public_url)
  end

  def public_url
    # Se sobrescribe con la URL real basada en subdominio en producción
    Rails.application.routes.url_helpers.pay_url(slug: slug, host: "#{user.organization.subdomain}.lvh.me", port: 3000)
  end

  private

  def generate_slug
    base = name.downcase.gsub(/[^a-z0-9\s]/, "").gsub(/\s+/, "-")
    self.slug = base
    counter = 1
    while Business.where(slug: self.slug).where.not(id: id).exists?
      self.slug = "#{base}-#{counter}"
      counter += 1
    end
  end
end
