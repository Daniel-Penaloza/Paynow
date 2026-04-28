class Receipt < ApplicationRecord
  belongs_to :business
  has_one_attached :file

  validates :file, presence: true
  validates :submitted_at, presence: true

  before_validation :set_submitted_at, on: :create

  private

  def set_submitted_at
    self.submitted_at ||= Time.current
  end
end
