class ElectiveSlotRule < ApplicationRecord
  DAY_NAMES = Date::DAYNAMES

  validates :day_of_week, presence: true, uniqueness: true, inclusion: { in: 0..6 }
  validates :slot_count, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :slot_duration_minutes, presence: true, numericality: { only_integer: true, greater_than: 0 }

  scope :ordered, -> { order(:day_of_week) }

  def self.by_day_of_week
    ordered.index_by(&:day_of_week)
  end

  def self.day_of_week_form_options
    DAY_NAMES.each_with_index.map { |name, index| [ name, index ] }
  end

  def day_name
    DAY_NAMES[day_of_week]
  end

  def slot_duration_hours
    (slot_duration_minutes / 60.0).round(1)
  end

  def total_minutes
    slot_count * slot_duration_minutes
  end

  def to_s
    "#{day_name} - #{slot_count} slots x #{slot_duration_minutes} min"
  end
end
