class Surgery < ApplicationRecord
  belongs_to :patient

  validates :surgery_date, presence: true
  validates :procedure, presence: true
  validates :anesthesia_method, presence: true
  validates :duration_minutes, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
end
