require "test_helper"

class SurgeriesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @surgery = surgeries(:one)
  end

  test "should get index" do
    get surgeries_url
    assert_response :success
  end

  test "index does not error out on a crafted Array page param" do
    get surgeries_url, params: { page: [ "1" ] }
    assert_response :success
  end

  test "index filters by keyword" do
    get surgeries_url, params: { keyword: "jane" }
    assert_response :success
    assert_match(/Jane Smith/, @response.body)
    assert_no_match(/John Doe/, @response.body)
  end

  test "index filters by anesthesia_method" do
    get surgeries_url, params: { anesthesia_method: "Spinal" }
    assert_response :success
    assert_match(/Jane Smith/, @response.body)
    assert_no_match(/John Doe/, @response.body)
  end

  test "index paginates results" do
    get surgeries_url, params: { page: 1 }
    assert_response :success
  end

  test "index filters by scheduling_type" do
    get surgeries_url, params: { scheduling_type: "emergency" }
    assert_response :success
    assert_match(/Emergency/, @response.body)
  end

  test "index shows the assigned slot, and flags elective surgeries without one" do
    get surgeries_url
    assert_response :success
    assert_match(/Slot 1/, @response.body)          # surgeries(:three) and (:four)
    assert_match(/No slot assigned/, @response.body) # surgeries(:six)
  end

  test "index shows the day's whole number of slots (total_slots), not the raw fractional slot_count" do
    ElectiveSlotRule.find_by(day_of_week: surgeries(:three).surgery_date.wday).update!(slot_count: 2.5, slot_duration_minutes: 240)

    get surgeries_url
    assert_response :success
    assert_match(%r{Slot 1 / 3}, @response.body)
    assert_no_match(/2\.5/, @response.body)
  end

  test "should get new" do
    get new_surgery_url
    assert_response :success
  end

  test "new shows the day's whole number of slots (total_slots) in the configured-slots hint" do
    ElectiveSlotRule.find_by(day_of_week: 2).update!(slot_count: 2.5, slot_duration_minutes: 240)

    get new_surgery_url

    assert_response :success
    assert_match(/Tuesday: 3/, @response.body)
    assert_no_match(/Tuesday: 2\.5/, @response.body)
  end

  test "new excludes discarded hospitalizations from the linked hospitalization dropdown" do
    hospitalizations(:one).discard!

    get new_surgery_url

    assert_response :success
    assert_select "select#surgery_hospitalization_id option[value='#{hospitalizations(:one).id}']", count: 0
    assert_select "select#surgery_hospitalization_id option[value='#{hospitalizations(:two).id}']", count: 1
  end

  test "should create surgery" do
    assert_difference("Surgery.count") do
      post surgeries_url, params: { surgery: {
        patient_id: patients(:one).id,
        patient_diagnosis_ids: [ patient_diagnoses(:appendicitis).id, patient_diagnoses(:hypertension).id ],
        surgery_date: "2026-03-03",
        anesthesia_method: "General",
        duration_hours: 2.0,
        surgery_procedure_selections_attributes: {
          "0" => { surgery_procedure_id: surgery_procedures(:cholecystectomy).id, laterality: "bilateral" },
          "1" => { surgery_procedure_id: surgery_procedures(:appendectomy).id, laterality: "left" }
        }
      } }
    end

    assert_redirected_to surgery_url(Surgery.last)
  assert_equal [ patient_diagnoses(:appendicitis).id, patient_diagnoses(:hypertension).id ].sort, Surgery.last.patient_diagnoses.ids.sort
    assert_equal [ "Cholecystectomy", "Appendectomy" ], Surgery.last.procedure_names
    assert_equal [ "bilateral", "left" ], Surgery.last.surgery_procedure_selections.order(:id).pluck(:laterality)
    assert_equal "Bilateral Cholecystectomy, Left Appendectomy", Surgery.last.display_procedure_name
  end

  test "should create a surgery with an undecided surgery_date" do
    assert_difference("Surgery.count") do
      post surgeries_url, params: { surgery: {
        patient_id: patients(:one).id,
        surgery_date: "",
        surgery_date_status: "undecided",
        anesthesia_method: "General",
        duration_hours: 1.0,
        surgery_procedure_selections_attributes: {
          "0" => { surgery_procedure_id: surgery_procedures(:appendectomy).id, laterality: "right" }
        }
      } }
    end

    assert_redirected_to surgery_url(Surgery.last)
    assert_nil Surgery.last.surgery_date
  end

  test "rejects a surgery marked scheduled with a blank surgery_date" do
    assert_no_difference("Surgery.count") do
      post surgeries_url, params: { surgery: {
        patient_id: patients(:one).id,
        surgery_date: "",
        surgery_date_status: "scheduled",
        anesthesia_method: "General",
        duration_hours: 1.0,
        surgery_procedure_selections_attributes: {
          "0" => { surgery_procedure_id: surgery_procedures(:appendectomy).id, laterality: "right" }
        }
      } }
    end

    assert_response :unprocessable_entity
  end

  test "should create a surgery with operator_name assistant_name and operation_order" do
    assert_difference("Surgery.count") do
      post surgeries_url, params: { surgery: {
        patient_id: patients(:one).id,
        surgery_date: "2026-03-05",
        operator_name: "Dr. A",
        assistant_name: "Dr. B",
        operation_order: 1,
        anesthesia_method: "General",
        duration_hours: 1.0,
        surgery_procedure_selections_attributes: {
          "0" => { surgery_procedure_id: surgery_procedures(:appendectomy).id, laterality: "right" }
        }
      } }
    end

    surgery = Surgery.last
    assert_equal "Dr. A", surgery.operator_name
    assert_equal "Dr. B", surgery.assistant_name
    assert_equal 1, surgery.operation_order
  end

  test "index filters by undated" do
    Surgery.create!(
      patient: patients(:one),
      surgery_date: nil,
      anesthesia_method: "General",
      duration_hours: 1.0,
      surgery_procedure_selections_attributes: [ { surgery_procedure_id: surgery_procedures(:appendectomy).id } ]
    )

    get surgeries_url, params: { undated: "1" }

    assert_response :success
    assert_match(/Undated/, @response.body)
  end

  test "should create an emergency surgery on an unconfigured weekday at night" do
    assert_difference("Surgery.count") do
      post surgeries_url, params: { surgery: {
        patient_id: patients(:one).id,
        patient_diagnosis_ids: [ patient_diagnoses(:appendicitis).id ],
        surgery_date: "2026-03-01",
        scheduling_type: "emergency",
        start_time: "02:15",
        anesthesia_method: "General",
        duration_hours: 1.0,
        surgery_procedure_selections_attributes: {
          "0" => { surgery_procedure_id: surgery_procedures(:appendectomy).id, laterality: "right" }
        }
      } }
    end

    assert_redirected_to surgery_url(Surgery.last)
    assert Surgery.last.emergency?
    assert_equal "02:15", Surgery.last.start_time_display
  end

  test "should create an elective surgery beyond the configured slot capacity" do
    assert_difference("Surgery.count") do
      post surgeries_url, params: { surgery: {
        patient_id: patients(:one).id,
        patient_diagnosis_ids: [ patient_diagnoses(:appendicitis).id ],
        surgery_date: "2026-03-03",
        scheduling_type: "elective",
        anesthesia_method: "General",
        duration_hours: 1.0,
        surgery_procedure_selections_attributes: {
          "0" => { surgery_procedure_id: surgery_procedures(:appendectomy).id, laterality: "right" }
        }
      } }
    end

    assert_redirected_to surgery_url(Surgery.last)
    assert Surgery.last.elective?
  end

  test "should create surgery linked to a hospitalization" do
    assert_difference("Surgery.count") do
      post surgeries_url, params: { surgery: {
        patient_id: patients(:one).id,
        hospitalization_id: hospitalizations(:one).id,
        patient_diagnosis_ids: [ patient_diagnoses(:appendicitis).id ],
        surgery_date: "2026-03-03",
        anesthesia_method: "General",
        duration_hours: 2.0,
        surgery_procedure_selections_attributes: {
          "0" => { surgery_procedure_id: surgery_procedures(:appendectomy).id, laterality: "right" }
        }
      } }
    end

    assert_redirected_to surgery_url(Surgery.last)
    assert_equal hospitalizations(:one), Surgery.last.hospitalization
  end

  test "should reject a surgery linked to another patient's hospitalization" do
    assert_no_difference("Surgery.count") do
      post surgeries_url, params: { surgery: {
        patient_id: patients(:two).id,
        hospitalization_id: hospitalizations(:one).id,
        patient_diagnosis_ids: [ patient_diagnoses(:pneumonia).id ],
        surgery_date: "2026-03-03",
        anesthesia_method: "General",
        duration_hours: 2.0,
        surgery_procedure_selections_attributes: {
          "0" => { surgery_procedure_id: surgery_procedures(:appendectomy).id, laterality: "right" }
        }
      } }
    end

    assert_response :unprocessable_entity
  end

  test "should show surgery" do
    get surgery_url(@surgery)
    assert_response :success
  end

  test "show does not issue additional queries for extra patient_diagnoses or procedure selections" do
    surgery = surgeries(:two) # starts with 1 diagnosis, 1 procedure selection
    fewer_queries = capture_query_count { get surgery_url(surgery) }

    extra_diagnosis = surgery.patient.patient_diagnoses.create!(diagnosis: diagnoses(:fracture), diagnosed_on: Date.new(2026, 4, 10))
    surgery.surgery_diagnosis_links.create!(patient_diagnosis: extra_diagnosis)
    surgery.surgery_procedure_selections.create!(surgery_procedure: surgery_procedures(:cholecystectomy))

    more_queries = capture_query_count { get surgery_url(surgery) } # now 2 diagnoses, 2 procedure selections

    assert_equal fewer_queries, more_queries
  end

  test "show displays a holiday badge when the surgery date is a holiday" do
    holiday = holidays(:national_holiday)
    surgery = Surgery.create!(
      patient: patients(:one),
      surgery_date: holiday.date,
      scheduling_type: "elective",
      anesthesia_method: "General",
      duration_hours: 1.0,
      surgery_procedure_selections_attributes: [ { surgery_procedure_id: surgery_procedures(:appendectomy).id } ]
    )

    get surgery_url(surgery)

    assert_response :success
    assert_match(/#{Regexp.escape(holiday.name)}/, @response.body)
  end

  test "show does not display a holiday badge on a non-holiday date" do
    get surgery_url(@surgery)
    assert_response :success
    assert_no_match(/Vernal Equinox Day/, @response.body)
  end

  test "show does not display a holiday badge for a comment-only day (holiday: false)" do
    note_only = Holiday.create!(date: @surgery.surgery_date, holiday: false, note: "Fire drill today")

    get surgery_url(@surgery)

    assert_response :success
    assert_select ".badge-secondary", count: 0
  ensure
    note_only&.destroy
  end

  test "show displays the day's whole number of slots (total_slots), not the raw fractional slot_count" do
    surgery = surgeries(:three) # Tuesday, slot_number 1
    ElectiveSlotRule.find_by(day_of_week: surgery.surgery_date.wday).update!(slot_count: 2.5, slot_duration_minutes: 240)

    get surgery_url(surgery)

    assert_response :success
    assert_match(%r{Slot 1 of 3}, @response.body)
    assert_no_match(/2\.5/, @response.body)
  end

  test "should get edit" do
    get edit_surgery_url(@surgery)
    assert_response :success
  end

  test "should update surgery" do
    patch surgery_url(@surgery), params: { surgery: {
      patient_id: @surgery.patient_id,
      patient_diagnosis_ids: [ patient_diagnoses(:appendicitis).id, patient_diagnoses(:hypertension).id ],
      surgery_date: @surgery.surgery_date,
      anesthesia_method: @surgery.anesthesia_method,
      duration_hours: @surgery.duration_hours,
      surgery_procedure_selections_attributes: {
        "0" => {
          id: surgery_procedure_selections(:one_appendectomy).id,
          surgery_procedure_id: surgery_procedures(:updated_procedure).id,
          laterality: "left"
        },
        "1" => {
          id: surgery_procedure_selections(:one_knee_arthroscopy).id,
          surgery_procedure_id: surgery_procedures(:appendectomy).id,
          laterality: "right"
        }
      }
    } }

    assert_redirected_to surgery_url(@surgery)
    @surgery.reload
    assert_equal [ patient_diagnoses(:appendicitis).id, patient_diagnoses(:hypertension).id ].sort, @surgery.patient_diagnoses.ids.sort
    assert_equal [ "Updated Procedure", "Appendectomy" ], @surgery.procedure_names
    assert_equal [ "left", "right" ], @surgery.surgery_procedure_selections.order(:id).pluck(:laterality)
    assert_equal "Left Updated Procedure, Right Appendectomy", @surgery.display_procedure_name
  end

  test "should respond with unprocessable entity when procedures are swapped between rows" do
    patch surgery_url(@surgery), params: { surgery: {
      patient_id: @surgery.patient_id,
      surgery_date: @surgery.surgery_date,
      anesthesia_method: @surgery.anesthesia_method,
      surgery_procedure_selections_attributes: {
        "0" => {
          id: surgery_procedure_selections(:one_appendectomy).id,
          surgery_procedure_id: surgery_procedures(:knee_arthroscopy).id
        },
        "1" => {
          id: surgery_procedure_selections(:one_knee_arthroscopy).id,
          surgery_procedure_id: surgery_procedures(:appendectomy).id
        }
      }
    } }

    assert_response :unprocessable_entity
    assert_equal [ "Appendectomy", "Knee arthroscopy" ], @surgery.reload.procedure_names
  end

  test "should not mask a unique violation from an unrelated constraint as a procedure swap error" do
    unrelated_violation = ActiveRecord::RecordNotUnique.new(
      "SQLite3::ConstraintException: UNIQUE constraint failed: surgery_diagnosis_links.surgery_id, surgery_diagnosis_links.patient_diagnosis_id"
    )

    Surgery.define_method(:update) { |*| raise unrelated_violation }

    assert_raises(ActiveRecord::RecordNotUnique) do
      patch surgery_url(@surgery), params: { surgery: {
        patient_id: @surgery.patient_id,
        surgery_date: @surgery.surgery_date,
        anesthesia_method: @surgery.anesthesia_method
      } }
    end
  ensure
    Surgery.remove_method(:update) if Surgery.instance_methods(false).include?(:update)
  end

  test "should reject diagnosis belonging to another patient" do
    assert_no_difference("Surgery.count") do
      post surgeries_url, params: { surgery: {
        patient_id: patients(:one).id,
        patient_diagnosis_ids: [ patient_diagnoses(:appendicitis).id, patient_diagnoses(:pneumonia).id ],
        surgery_date: "2026-03-03",
        anesthesia_method: "General",
        duration_hours: 2.0,
        surgery_procedure_selections_attributes: {
          "0" => { surgery_procedure_id: surgery_procedures(:appendectomy).id, laterality: "right" }
        }
      } }
    end

    assert_response :unprocessable_entity
  end

  test "should destroy surgery" do
    assert_difference("Surgery.count", -1) do
      delete surgery_url(@surgery)
    end

    assert_redirected_to surgeries_url
  end

  private

    def capture_query_count
      count = 0
      counter = ->(*) { count += 1 }
      ActiveSupport::Notifications.subscribed(counter, "sql.active_record") { yield }
      count
    end
end
