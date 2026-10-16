# The lanes (列) a special slot resource has on one calendar date, replacing its
# weekly SpecialSlotRule count for that date (the hybrid room is usually fixed
# by weekday, but a given day may differ). Zero means no lane that day. A
# resource needs no weekly rule: an override alone makes it special on its date.
# A closed Holiday still has no lanes, whatever is stored here (as for regular
# slots, see ElectiveSlotUsage). Not audited, like the Holiday/day-note edits.
class SpecialSlotDayOverride < ApplicationRecord
  belongs_to :resource, polymorphic: true

  validates :resource_type, inclusion: { in: SpecialSlotRule::RESOURCE_TYPES }
  validates :date, presence: true, uniqueness: { scope: %i[resource_type resource_id] }
  validates :slot_count, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  scope :open, -> { where("slot_count > 0") }
end
