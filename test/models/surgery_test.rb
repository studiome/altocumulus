require "test_helper"

class SurgeryTest < ActiveSupport::TestCase
  test "should be valid" do
    surgery = Surgery.new(
      patient: patients(:one),
      surgery_date: Date.new(2026, 3, 1),
      anesthesia_method: "General",
      duration_hours: 1.5,
      surgery_procedure_selections_attributes: [
        { surgery_procedure_id: surgery_procedures(:appendectomy).id, laterality: "right" },
        { surgery_procedure_id: surgery_procedures(:knee_arthroscopy).id, laterality: "left" }
      ]
    )

    assert surgery.valid?
  end

  test "should require surgery_date" do
    surgery = surgeries(:one)
    surgery.surgery_date = nil
    assert_not surgery.valid?
  end

  test "first procedure_names entry reflects first selection" do
    surgery = Surgery.new(
      patient: patients(:one),
      surgery_date: Date.new(2026, 3, 1),
      anesthesia_method: "General",
      duration_hours: 1.5,
      surgery_procedure_selections_attributes: [
        { surgery_procedure_id: surgery_procedures(:cholecystectomy).id, laterality: "bilateral" },
        { surgery_procedure_id: surgery_procedures(:appendectomy).id, laterality: "left" }
      ]
    )

    assert surgery.valid?
    assert_equal "Cholecystectomy", surgery.procedure_names.first
  end

  test "should require at least one procedure selection" do
    surgery = Surgery.new(
      patient: patients(:one),
      surgery_date: Date.new(2026, 3, 1),
      anesthesia_method: "General",
      duration_hours: 1.5
    )

    assert_not surgery.valid?
    assert_includes surgery.errors[:surgery_procedure_selections], "must include at least one procedure"
  end

  test "should limit procedure selections to five" do
    surgery = Surgery.new(
      patient: patients(:one),
      surgery_date: Date.new(2026, 3, 1),
      anesthesia_method: "General",
      duration_hours: 1.5,
      surgery_procedure_selections_attributes: [
        { surgery_procedure_id: surgery_procedures(:appendectomy).id, laterality: "right" },
        { surgery_procedure_id: surgery_procedures(:knee_arthroscopy).id, laterality: "left" },
        { surgery_procedure_id: surgery_procedures(:cholecystectomy).id, laterality: "bilateral" },
        { surgery_procedure_id: surgery_procedures(:updated_procedure).id, laterality: "none" },
        { surgery_procedure_id: surgery_procedures(:appendectomy).id, laterality: "right" },
        { surgery_procedure_id: surgery_procedures(:knee_arthroscopy).id, laterality: "left" }
      ]
    )

    assert_not surgery.valid?
    assert_includes surgery.errors[:surgery_procedure_selections], "must be five or fewer"
  end

  test "should reject duplicate procedure selections" do
    surgery = Surgery.new(
      patient: patients(:one),
      surgery_date: Date.new(2026, 3, 1),
      anesthesia_method: "General",
      duration_hours: 1.5,
      surgery_procedure_selections_attributes: [
        { surgery_procedure_id: surgery_procedures(:appendectomy).id, laterality: "right" },
        { surgery_procedure_id: surgery_procedures(:appendectomy).id, laterality: "left" }
      ]
    )

    assert_not surgery.valid?
    assert_includes surgery.errors[:surgery_procedure_selections], "must not include duplicate procedures"
  end

  test "should require anesthesia_method" do
    surgery = surgeries(:one)
    surgery.anesthesia_method = nil
    assert_not surgery.valid?
  end

  test "duration_hours should be non-negative" do
    surgery = surgeries(:one)
    surgery.duration_hours = -1.0
    assert_not surgery.valid?
  end

  test "display_procedure_name should omit laterality when none" do
    surgery = Surgery.new(
      patient: patients(:one),
      surgery_date: Date.new(2026, 3, 1),
      anesthesia_method: "General",
      duration_hours: 1.5,
      surgery_procedure_selections_attributes: [
        { surgery_procedure_id: surgery_procedures(:appendectomy).id, laterality: "none" },
        { surgery_procedure_id: surgery_procedures(:knee_arthroscopy).id, laterality: "left" }
      ]
    )

    assert_equal "Appendectomy、Left Knee arthroscopy", surgery.display_procedure_name
  end

  test "display_procedure_name should prefix laterality when present" do
    surgery = Surgery.new(
      patient: patients(:one),
      surgery_date: Date.new(2026, 3, 1),
      anesthesia_method: "General",
      duration_hours: 1.5,
      surgery_procedure_selections_attributes: [
        { surgery_procedure_id: surgery_procedures(:appendectomy).id, laterality: "right" },
        { surgery_procedure_id: surgery_procedures(:knee_arthroscopy).id, laterality: "bilateral" }
      ]
    )

    assert_equal "Right Appendectomy、Bilateral Knee arthroscopy", surgery.display_procedure_name
  end

  test "should allow a surgery linked to a hospitalization of the same patient within its period" do
    surgery = Surgery.new(
      patient: patients(:one),
      hospitalization: hospitalizations(:one),
      surgery_date: Date.new(2026, 3, 3),
      anesthesia_method: "General",
      duration_hours: 1.5,
      surgery_procedure_selections_attributes: [
        { surgery_procedure_id: surgery_procedures(:appendectomy).id, laterality: "right" }
      ]
    )

    assert surgery.valid?
  end

  test "should reject a hospitalization belonging to a different patient" do
    surgery = Surgery.new(
      patient: patients(:two),
      hospitalization: hospitalizations(:one),
      surgery_date: Date.new(2026, 3, 3),
      anesthesia_method: "General",
      duration_hours: 1.5,
      surgery_procedure_selections_attributes: [
        { surgery_procedure_id: surgery_procedures(:appendectomy).id, laterality: "right" }
      ]
    )

    assert_not surgery.valid?
    assert_includes surgery.errors[:hospitalization], "must belong to the same patient as the surgery"
  end

  test "should reject a surgery_date before the hospitalization's admission_date" do
    surgery = Surgery.new(
      patient: patients(:one),
      hospitalization: hospitalizations(:one),
      surgery_date: hospitalizations(:one).admission_date - 1,
      anesthesia_method: "General",
      duration_hours: 1.5,
      surgery_procedure_selections_attributes: [
        { surgery_procedure_id: surgery_procedures(:appendectomy).id, laterality: "right" }
      ]
    )

    assert_not surgery.valid?
    assert_includes surgery.errors[:surgery_date], "must fall within the linked hospitalization period"
  end

  test "should reject a surgery_date after the hospitalization's discharge_date" do
    surgery = Surgery.new(
      patient: patients(:one),
      hospitalization: hospitalizations(:one),
      surgery_date: hospitalizations(:one).discharge_date + 1,
      anesthesia_method: "General",
      duration_hours: 1.5,
      surgery_procedure_selections_attributes: [
        { surgery_procedure_id: surgery_procedures(:appendectomy).id, laterality: "right" }
      ]
    )

    assert_not surgery.valid?
    assert_includes surgery.errors[:surgery_date], "must fall within the linked hospitalization period"
  end

  test "should allow any surgery_date on or after admission for an ongoing hospitalization" do
    surgery = Surgery.new(
      patient: patients(:one),
      hospitalization: hospitalizations(:three),
      surgery_date: hospitalizations(:three).admission_date + 30,
      anesthesia_method: "General",
      duration_hours: 1.5,
      surgery_procedure_selections_attributes: [
        { surgery_procedure_id: surgery_procedures(:appendectomy).id, laterality: "right" }
      ]
    )

    assert surgery.valid?
  end

  test "linked_to_hospitalization and standalone scopes" do
    linked = Surgery.create!(
      patient: patients(:one),
      hospitalization: hospitalizations(:one),
      surgery_date: Date.new(2026, 3, 3),
      anesthesia_method: "General",
      duration_hours: 1.5,
      surgery_procedure_selections_attributes: [
        { surgery_procedure_id: surgery_procedures(:appendectomy).id, laterality: "right" }
      ]
    )

    assert_includes Surgery.linked_to_hospitalization, linked
    assert_not_includes Surgery.linked_to_hospitalization, surgeries(:one)

    assert_includes Surgery.standalone, surgeries(:one)
    assert_not_includes Surgery.standalone, linked
  end

  test "filtered with no filters returns everything" do
    assert_equal Surgery.count, Surgery.filtered(keyword: nil, surgery_procedure_id: nil, anesthesia_method: nil, performed_from: nil, performed_to: nil).count
  end

  test "filtered by keyword matches patient name or hospital_id" do
    assert_equal [ surgeries(:two), surgeries(:four), surgeries(:six) ].sort_by(&:id), Surgery.filtered(keyword: "jane").sort_by(&:id)
    assert_equal [ surgeries(:one), surgeries(:three), surgeries(:five), surgeries(:emergency_one) ].sort_by(&:id), Surgery.filtered(keyword: "H001").sort_by(&:id)
  end

  test "filtered by keyword escapes LIKE wildcards" do
    assert_equal [], Surgery.filtered(keyword: "%").to_a
  end

  test "filtered by surgery_procedure_id matches only surgeries using it" do
    expected = [ surgeries(:one), surgeries(:three), surgeries(:four), surgeries(:emergency_one) ].sort_by(&:id)
    assert_equal expected, Surgery.filtered(surgery_procedure_id: surgery_procedures(:appendectomy).id).sort_by(&:id)
  end

  test "filtered by anesthesia_method matches exactly" do
    expected = [ surgeries(:one), surgeries(:three), surgeries(:four), surgeries(:five), surgeries(:six), surgeries(:emergency_one) ].sort_by(&:id)
    assert_equal expected, Surgery.filtered(anesthesia_method: "General").sort_by(&:id)
  end

  test "filtered by performed_from and performed_to narrows the surgery date range" do
    result = Surgery.filtered(performed_from: "2026-03-02", performed_to: "2026-03-31")
    expected = [ surgeries(:two), surgeries(:three), surgeries(:four), surgeries(:five), surgeries(:six) ].sort_by(&:id)
    assert_equal expected, result.sort_by(&:id)
  end

  test "anesthesia_methods scope returns distinct sorted non-blank methods" do
    assert_equal [ "General", "Spinal" ], Surgery.anesthesia_methods
  end

  test "scheduling_type defaults to elective" do
    assert_equal "elective", surgeries(:one).scheduling_type
  end

  test "scheduling_type must be elective or emergency" do
    surgery = surgeries(:one)

    surgery.scheduling_type = "urgent"
    assert_not surgery.valid?

    surgery.scheduling_type = nil
    assert_not surgery.valid?

    surgery.scheduling_type = "emergency"
    assert surgery.valid?
  end

  test "elective? and emergency? and scheduling_type_label" do
    assert surgeries(:one).elective?
    assert_not surgeries(:one).emergency?
    assert_equal "Elective", surgeries(:one).scheduling_type_label

    assert surgeries(:emergency_one).emergency?
    assert_not surgeries(:emergency_one).elective?
    assert_equal "Emergency", surgeries(:emergency_one).scheduling_type_label
  end

  test "elective and emergency scopes" do
    assert_includes Surgery.elective, surgeries(:one)
    assert_not_includes Surgery.elective, surgeries(:emergency_one)

    assert_includes Surgery.emergency, surgeries(:emergency_one)
    assert_not_includes Surgery.emergency, surgeries(:one)
  end

  test "start_time_display formats a start_time or shows a dash" do
    assert_equal "23:30", surgeries(:emergency_one).start_time_display
    assert_equal "-", surgeries(:one).start_time_display
  end

  test "an emergency surgery can be saved on an unconfigured weekday at night" do
    surgery = Surgery.new(
      patient: patients(:one),
      surgery_date: Date.new(2026, 3, 1), # Sunday, no elective slot rule configured
      scheduling_type: "emergency",
      start_time: "02:00",
      anesthesia_method: "General",
      duration_hours: 1.0,
      surgery_procedure_selections_attributes: [
        { surgery_procedure_id: surgery_procedures(:appendectomy).id, laterality: "right" }
      ]
    )

    assert surgery.valid?
  end

  test "an elective surgery beyond slot capacity is still valid" do
    surgery = Surgery.new(
      patient: patients(:one),
      surgery_date: Date.new(2026, 3, 3), # Tuesday, already at 4 elective surgeries in 3 slots
      scheduling_type: "elective",
      anesthesia_method: "General",
      duration_hours: 1.0,
      surgery_procedure_selections_attributes: [
        { surgery_procedure_id: surgery_procedures(:appendectomy).id, laterality: "right" }
      ]
    )

    assert surgery.valid?
  end

  test "an elective surgery longer than its slot duration is still valid" do
    surgery = surgeries(:five)
    assert surgery.valid?
  end

  test "slot_overrun_minutes is nil for emergency surgeries regardless of rule" do
    rule = elective_slot_rules(:tuesday)
    assert_nil surgeries(:emergency_one).slot_overrun_minutes(rule)
  end

  test "slot_overrun_minutes is nil when no rule is given" do
    assert_nil surgeries(:one).slot_overrun_minutes(nil)
  end

  test "slot_overrun_minutes is nil when the surgery fits within the slot" do
    rule = elective_slot_rules(:tuesday)
    assert_nil surgeries(:three).slot_overrun_minutes(rule)
  end

  test "slot_overrun_minutes returns the number of minutes past the slot duration" do
    rule = elective_slot_rules(:tuesday)
    assert_equal 60, surgeries(:five).slot_overrun_minutes(rule)
    assert surgeries(:five).slot_overrun?(rule)
  end

  test "filtered by scheduling_type" do
    assert_equal [ surgeries(:emergency_one) ], Surgery.filtered(scheduling_type: "emergency").to_a
  end
end
