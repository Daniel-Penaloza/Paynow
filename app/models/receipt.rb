class Receipt < ApplicationRecord
  belongs_to :business
  has_one_attached :file

  VERIFICATION_STATUSES = %w[pending verified rejected unreadable].freeze

  validates :file, presence: true
  validates :submitted_at, presence: true
  validates :verification_status, inclusion: { in: VERIFICATION_STATUSES }

  before_validation :set_submitted_at, on: :create

  # Filtros por fecha de subida
  scope :today,      -> { where(submitted_at: Time.current.beginning_of_day..Time.current.end_of_day) }
  scope :this_week,  -> { where(submitted_at: Time.current.beginning_of_week..Time.current.end_of_week) }
  scope :this_month, -> { where(submitted_at: Time.current.beginning_of_month..Time.current.end_of_month) }
  scope :this_year,  -> { where(submitted_at: Time.current.beginning_of_year..Time.current.end_of_year) }
  scope :between,    ->(from, to) { where(submitted_at: from.beginning_of_day..to.end_of_day) }

  # Filtros por status de verificación
  scope :pending,     -> { where(verification_status: "pending") }
  scope :verified,    -> { where(verification_status: "verified") }
  scope :rejected,    -> { where(verification_status: "rejected") }
  scope :unreadable,  -> { where(verification_status: "unreadable") }

  def amount
    amount_cents ? amount_cents / 100.0 : nil
  end

  def amount=(value)
    self.amount_cents = value.present? ? (value.to_f * 100).round : nil
  end

  after_create_commit :broadcast_to_dashboard
  after_create_commit :enqueue_verification

  private

  def set_submitted_at
    self.submitted_at ||= Time.current
  end

  def enqueue_verification
    ReceiptVerificationJob.perform_later(id)
  end

  def broadcast_to_dashboard
    # Actualiza la lista de comprobantes en business#show
    broadcast_prepend_to(
      "business_#{business_id}_receipts",
      target: "receipts_list",
      partial: "dashboard/receipts/receipt",
      locals: { receipt: self, business: business }
    )

    # Toast de notificación visible en cualquier página del dashboard
    broadcast_prepend_to(
      "user_#{business.user_id}_notifications",
      target: "toast_notifications",
      partial: "dashboard/shared/toast_notification",
      locals: { receipt: self }
    )
  end
end
