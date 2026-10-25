# How many lanes (列) of a special slot resource -- a SurgeryLocation or a
# SurgicalDevice, see SpecialSlotResource -- are open on a weekday. A lane is
# one regular slot's length of time that cases share while they fit (see
# ElectiveSlotUsage::SpecialSlot), used on top of their regular slot. Zero (or
# no row) means no lane that weekday.
class SpecialSlotRule < ApplicationRecord
  RESOURCE_TYPES = %w[SurgeryLocation SurgicalDevice].freeze

  belongs_to :resource, polymorphic: true

  validates :resource_type, inclusion: { in: RESOURCE_TYPES }
  validates :day_of_week, presence: true, inclusion: { in: 0..6 }, uniqueness: { scope: %i[resource_type resource_id] }
  validates :slot_count, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  scope :open, -> { where("slot_count > 0") }
end
