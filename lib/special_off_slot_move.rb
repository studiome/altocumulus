# One-off conversion for data entered before special slots (特殊枠) existed:
# hybrid room / cath lab / robot cases were recorded as off_slot, which
# consumes neither a regular slot nor any lane. The correct form is a regular
# case (slot unassigned, to be placed by hand) that also names the special
# resource, so this moves every elective off-slot surgery whose location or
# device is a special slot resource (has a lane rule with slot_count > 0).
#
# Emergency surgeries are left alone: they never take slots or lanes, so their
# category changes nothing about capacity. The move goes through
# `Surgery#update` (not update_columns), so validations, callbacks and the
# audit trail (Auditable) apply as for any edit; the audit event carries no
# user (a console task has no Current.user). Idempotent: a moved surgery is no
# longer off_slot. A surgery that fails validation is reported and skipped.
class SpecialOffSlotMove
  Result = Struct.new(:candidates, :moved, :failed)

  def initialize(apply: false)
    @apply = apply
  end

  def apply?
    @apply
  end

  def candidates
    location_ids = special_ids("SurgeryLocation")
    device_ids = special_ids("SurgicalDevice")
    Surgery.elective.where(slot_category: "off_slot")
           .where(surgery_location_id: location_ids).or(
             Surgery.elective.where(slot_category: "off_slot").where(surgical_device_id: device_ids)
           )
           .includes(:patient, :surgery_location, :surgical_device).order(:surgery_date, :id).to_a
  end

  def run
    found = candidates
    moved = 0
    failed = []
    if apply?
      found.each do |surgery|
        if surgery.update(slot_category: "regular", slot_number: nil)
          moved += 1
        else
          failed << [ surgery.id, surgery.errors.full_messages.to_sentence ]
        end
      end
    end
    Result.new(found, moved, failed)
  end

  private

    def special_ids(type)
      SpecialSlotRule.open.where(resource_type: type).distinct.pluck(:resource_id)
    end
end
