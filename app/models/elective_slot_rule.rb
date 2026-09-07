class ElectiveSlotRule < ApplicationRecord
  DAY_NAMES = Date::DAYNAMES

  validates :day_of_week, presence: true, uniqueness: true, inclusion: { in: 0..6 }
  validates :slot_count, presence: true, numericality: { greater_than: 0 }
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

  # slot_count may be fractional (e.g. 2.5), meaning the day's last slot is
  # shorter than the rest rather than there being an extra whole slot.
  # total_minutes keeps that fraction uncollapsed for calculations; round it
  # only when displaying.
  def total_minutes
    slot_count * slot_duration_minutes
  end

  def total_minutes_display
    format_decimal(total_minutes)
  end

  # The number of slots the day actually has. Always use this (never
  # `(1..slot_count)` directly) since Ruby silently floors a fractional Range
  # endpoint and would drop the short last slot.
  def total_slots
    slot_count.ceil
  end

  # One duration per slot, in order. Every slot but a fractional last one
  # gets the full slot_duration_minutes; the remainder (if any) becomes the
  # last slot's shortened duration.
  def slot_durations
    whole_slots = slot_count.floor
    fraction = slot_count - whole_slots
    durations = Array.new(whole_slots, slot_duration_minutes)
    durations << (slot_duration_minutes * fraction).round if fraction.positive?
    durations
  end

  # slot_count as the operator entered it (e.g. "2.5"), but without a
  # trailing ".0" when it happens to be a whole number.
  def slot_count_display
    format_decimal(slot_count)
  end

  def to_s
    "#{day_name} - #{slot_count_display} slots x #{slot_duration_minutes} min"
  end

  private

    def format_decimal(value)
      decimal = value.is_a?(BigDecimal) ? value : BigDecimal(value.to_s)
      decimal.round(1).to_s("F").sub(/\.0\z/, "")
    end
end
