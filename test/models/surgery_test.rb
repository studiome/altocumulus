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

  # surgery_date is no longer required outright: a surgery can be "undecided"
  # (see the surgery_date_status tests below). An update that never touches
  # surgery_date_status at all (dup, seeds, console, this direct assignment)
  # must not be blocked by the contradiction check either.
  test "surgery_date can be left blank without explicitly setting surgery_date_status" do
    surgery = surgeries(:one)
    surgery.surgery_date = nil
    assert surgery.valid?
  end

  test "surgery_date_status defaults to scheduled for a new record and undecided once persisted without a date" do
    assert_equal "scheduled", Surgery.new.surgery_date_status

    persisted = surgeries(:one)
    assert_equal "scheduled", persisted.surgery_date_status

    persisted.surgery_date = nil
    assert_equal "undecided", persisted.surgery_date_status
  end

  test "rejects surgery_date_status scheduled with a blank surgery_date" do
    surgery = surgeries(:one)
    surgery.surgery_date = nil
    surgery.surgery_date_status = "scheduled"

    assert_not surgery.valid?
    assert_includes surgery.errors[:surgery_date], "must be entered, or choose Undecided"
  end

  test "rejects surgery_date_status undecided with a surgery_date present" do
    surgery = surgeries(:one)
    surgery.surgery_date_status = "undecided"

    assert_not surgery.valid?
    assert_includes surgery.errors[:surgery_date], "must be left blank when marked as undecided"
  end

  test "accepts surgery_date_status undecided together with a blank surgery_date" do
    surgery = surgeries(:one)
    surgery.surgery_date = nil
    surgery.surgery_date_status = "undecided"

    assert surgery.valid?
  end

  test "accepts surgery_date_status scheduled together with a present surgery_date" do
    surgery = surgeries(:one)
    surgery.surgery_date_status = "scheduled"

    assert surgery.valid?
  end

  test "rejects an invalid surgery_date_status value" do
    surgery = surgeries(:one)
    surgery.surgery_date_status = "someday"

    assert_not surgery.valid?
    assert_includes surgery.errors[:surgery_date_status], "is not valid"
  end

  test "does not enforce the surgery_date contradiction check unless surgery_date_status is explicitly assigned" do
    # dup does not carry over the has_many procedure selections, so the
    # duplicate is invalid for an unrelated reason; what matters here is that
    # the surgery_date contradiction check specifically stays silent.
    duplicate = surgeries(:one).dup
    duplicate.surgery_date = nil

    duplicate.valid?

    assert_empty duplicate.errors[:surgery_date], "duplicating/updating without touching surgery_date_status must not trigger the contradiction check"
  end

  test "an undated surgery linked to a hospitalization skips the hospitalization period check" do
    surgery = Surgery.new(
      patient: patients(:one),
      hospitalization: hospitalizations(:one),
      surgery_date: nil,
      anesthesia_method: "General",
      duration_hours: 1.0,
      surgery_procedure_selections_attributes: [
        { surgery_procedure_id: surgery_procedures(:appendectomy).id, laterality: "right" }
      ]
    )

    assert surgery.valid?
  end

  test "operator_name assistant_name and operation_order can be recorded" do
    surgery = surgeries(:one)
    surgery.update!(operator_name: "Dr. Smith", assistant_name: "Dr. Lee", operation_order: 2)

    surgery.reload
    assert_equal "Dr. Smith", surgery.operator_name
    assert_equal "Dr. Lee", surgery.assistant_name
    assert_equal 2, surgery.operation_order
  end

  test "operation_order must be a positive integer when given" do
    surgery = surgeries(:one)

    surgery.operation_order = 0
    assert_not surgery.valid?

    surgery.operation_order = 1.5
    assert_not surgery.valid?

    surgery.operation_order = nil
    assert surgery.valid?

    surgery.operation_order = 1
    assert surgery.valid?
  end

  test "ordered_by_surgery_date sorts undated surgeries after dated ones" do
    undated = create_undated_surgery

    ordered = Surgery.where(id: [ surgeries(:one).id, undated.id ]).ordered_by_surgery_date

    assert_equal undated, ordered.last
  ensure
    undated&.destroy
  end

  test "filtered excludes undated surgeries when a performed date range is given" do
    undated = create_undated_surgery

    result = Surgery.filtered(performed_from: "2026-01-01", performed_to: "2026-12-31")

    assert_not_includes result, undated
  ensure
    undated&.destroy
  end

  test "filtered with undated true returns only undated surgeries" do
    undated = create_undated_surgery

    result = Surgery.filtered(undated: true)

    assert_equal [ undated ], result.to_a
  ensure
    undated&.destroy
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

  test "should allow a surgery within the scheduled period of a reservation-only hospitalization" do
    hospitalization = Hospitalization.create!(
      patient: patients(:two),
      scheduled_admission_date: Date.new(2026, 9, 10),
      reason: "Planned surgery",
      hospitalization_diagnoses_attributes: [ { diagnosis_id: diagnoses(:pneumonia).id } ]
    )

    surgery = Surgery.new(
      patient: patients(:two),
      hospitalization: hospitalization,
      surgery_date: Date.new(2026, 9, 12),
      anesthesia_method: "General",
      duration_hours: 1.5,
      surgery_procedure_selections_attributes: [
        { surgery_procedure_id: surgery_procedures(:appendectomy).id, laterality: "right" }
      ]
    )

    assert surgery.valid?
  end

  test "should reject a surgery_date before the scheduled_admission_date of a reservation-only hospitalization" do
    hospitalization = Hospitalization.create!(
      patient: patients(:two),
      scheduled_admission_date: Date.new(2026, 9, 10),
      reason: "Planned surgery",
      hospitalization_diagnoses_attributes: [ { diagnosis_id: diagnoses(:pneumonia).id } ]
    )

    surgery = Surgery.new(
      patient: patients(:two),
      hospitalization: hospitalization,
      surgery_date: Date.new(2026, 9, 9),
      anesthesia_method: "General",
      duration_hours: 1.5,
      surgery_procedure_selections_attributes: [
        { surgery_procedure_id: surgery_procedures(:appendectomy).id, laterality: "right" }
      ]
    )

    assert_not surgery.valid?
    assert_includes surgery.errors[:surgery_date], "must fall within the linked hospitalization period"
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

  test "duration_minutes converts duration_hours, and is nil when unrecorded" do
    assert_equal 60, surgeries(:three).duration_minutes
    assert_equal 300, surgeries(:five).duration_minutes
    assert_nil Surgery.new(duration_hours: nil).duration_minutes
  end

  test "slot_number must be a positive integer when given" do
    surgery = surgeries(:three)

    surgery.slot_number = 0
    assert_not surgery.valid?

    surgery.slot_number = -1
    assert_not surgery.valid?

    surgery.slot_number = 1.5
    assert_not surgery.valid?

    surgery.slot_number = 2
    assert surgery.valid?
  end

  test "slot_number may be left blank so a surgery can wait to be scheduled" do
    surgery = surgeries(:three)
    surgery.slot_number = nil

    assert surgery.valid?
  end

  # Emergency surgeries never occupy an elective slot, but they must still be
  # saveable on any date at any time, so the slot number is cleared rather
  # than rejected.
  test "switching a surgery to emergency clears its slot number instead of failing" do
    surgery = surgeries(:three)
    assert_equal 1, surgery.slot_number

    surgery.scheduling_type = "emergency"

    assert surgery.valid?
    assert_nil surgery.slot_number
  end

  test "an emergency surgery given a slot number saves with it cleared" do
    surgery = surgeries(:emergency_one)
    surgery.slot_number = 3

    assert surgery.save
    assert_nil surgery.reload.slot_number
  end

  test "filtered by scheduling_type" do
    assert_equal [ surgeries(:emergency_one) ], Surgery.filtered(scheduling_type: "emergency").to_a
  end

  test "diagnosis_names_display does not issue additional queries when patient_diagnoses are preloaded" do
    surgeries = Surgery.includes(patient_diagnoses: :diagnosis).where(id: [ surgeries(:one).id, surgeries(:two).id ]).load

    assert_queries_count(0) do
      surgeries.each(&:diagnosis_names_display)
    end
  end

  private

    def create_undated_surgery
      Surgery.create!(
        patient: patients(:one),
        surgery_date: nil,
        anesthesia_method: "General",
        duration_hours: 1.0,
        surgery_procedure_selections_attributes: [
          { surgery_procedure_id: surgery_procedures(:appendectomy).id, laterality: "right" }
        ]
      )
    end
end
