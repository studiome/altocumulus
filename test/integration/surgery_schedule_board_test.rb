require "test_helper"

class SurgeryScheduleBoardTest < ActionDispatch::IntegrationTest
  # 2026-09-01 is a Tuesday, so it picks up the Tuesday slot rule.
  TUESDAY = Date.new(2026, 9, 1)

  setup do
    ElectiveSlotRule.find_by(day_of_week: TUESDAY.wday).update!(slot_count: 1, slot_duration_minutes: 240)
  end

  # A slot is a whole day of one operating room, so several surgeries sharing
  # it is the normal case, not an error.
  test "shows several surgeries inside one slot without flagging the slot" do
    create_elective_surgery(duration_hours: 1.0, slot_number: 1)
    create_elective_surgery(duration_hours: 1.5, slot_number: 1)

    get surgery_schedule_url(week_of: TUESDAY.to_s)

    assert_select ".badge", text: /min over/, count: 0,
                  message: "150 min of surgery fits inside a 240 min slot"
    assert_match(%r{150 / 240 min}, @response.body)
  end

  test "flags the slot, not the individual surgeries, when their combined time overruns" do
    create_elective_surgery(duration_hours: 1.0, slot_number: 1)
    create_elective_surgery(duration_hours: 5.0, slot_number: 1)

    get surgery_schedule_url(week_of: TUESDAY.to_s)

    assert_select ".badge", text: /\+120 min over/, count: 1,
                  message: "360 min booked into a 240 min slot is 120 min over"
    assert_match(/Slot 1 is booked 120 min past its 240 min limit\./, @response.body)
  end

  test "lists an elective surgery with no slot number as unassigned" do
    create_elective_surgery(duration_hours: 1.0, slot_number: nil)

    get surgery_schedule_url(week_of: TUESDAY.to_s)

    assert_match(/Not assigned to a slot/, @response.body)
    assert_match(/1 elective surgery is not assigned to an available slot\./, @response.body)
  end

  test "orders each day's elective surgeries deterministically" do
    later = create_elective_surgery(duration_hours: 1.0, slot_number: 1)
    earlier = create_elective_surgery(duration_hours: 1.0, slot_number: 1)
    later.update!(start_time: "13:00")
    earlier.update!(start_time: "09:00")

    usage = ElectiveSlotUsage.for_dates([ TUESDAY ]).fetch(TUESDAY)

    assert_equal [ earlier.id, later.id ], usage.elective_surgeries.map(&:id)
    assert_equal [ earlier.id, later.id ], usage.slots.first.surgeries.map(&:id)
  end

  private

    def create_elective_surgery(duration_hours:, slot_number: 1)
      patient = Patient.create!(hospital_id: "B#{SecureRandom.hex(3)}", name: "Board Case",
                                date_of_birth: Date.new(1970, 1, 1))
      surgery = Surgery.new(patient: patient, surgery_date: TUESDAY, anesthesia_method: "General",
                            duration_hours: duration_hours, scheduling_type: "elective",
                            slot_number: slot_number)
      surgery.surgery_procedure_selections.build(surgery_procedure: surgery_procedures(:appendectomy))
      surgery.save!
      surgery
    end
end
