class Todo < ApplicationRecord
  validates :title, presence: true, length: { maximum: 255 }

  scope :completed, -> { where(completed: true) }
  scope :pending, -> { where(completed: false) }
end
