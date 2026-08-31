require "test_helper"

class SurgeryScheduleBoardTest < ActionDispatch::IntegrationTest
  # 2026-09-01 is a Tuesday, so it picks up the Tuesday slot rule.
  TUESDAY = Date.new(2026, 9, 1)

  setup do
    ElectiveSlotRule.find_by(day_of_week: TUESDAY.wday).update!(slot_count: 1, slot_duration_minutes: 240)
  end

  test "shows the extension badge for a surgery pushed past the day's capacity" do
    create_elective_surgery(duration_hours: 1.0)
    create_elective_surgery(duration_hours: 5.0)

    get surgery_schedule_url(week_of: TUESDAY.to_s)

    assert_select ".badge", text: /Extended \+60 min/,
                  count: 1, message: "the over-capacity surgery should still show that it extends its slot"
  end

  test "orders each day's elective surgeries deterministically" do
    later = create_elective_surgery(duration_hours: 1.0)
    earlier = create_elective_surgery(duration_hours: 1.0)
    later.update!(start_time: "13:00")
    earlier.update!(start_time: "09:00")

    usage = ElectiveSlotUsage.for_dates([ TUESDAY ]).fetch(TUESDAY)

    assert_equal [ earlier.id, later.id ], usage.elective_surgeries.map(&:id)
  end

  private

    def create_elective_surgery(duration_hours:)
      patient = Patient.create!(hospital_id: "B#{SecureRandom.hex(3)}", name: "Board Case",
                                date_of_birth: Date.new(1970, 1, 1))
      surgery = Surgery.new(patient: patient, surgery_date: TUESDAY, anesthesia_method: "General",
                            duration_hours: duration_hours, scheduling_type: "elective")
      surgery.surgery_procedure_selections.build(surgery_procedure: surgery_procedures(:appendectomy))
      surgery.save!
      surgery
    end
end
